import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { CancellationToken } from '../../core/network/CancellationToken';
import { HttpError, HttpErrorCode } from '../../core/network/HttpError';
import { HttpBody, HttpMethod, HttpResponse, HttpResponseHeaders, HttpResponseType, HttpTransport,
  PreparedHttpRequest } from '../../core/network/HttpTypes';

export class HarmonyHttpTransport implements HttpTransport {
  send(request: PreparedHttpRequest, cancellation?: CancellationToken): Promise<HttpResponse> {
    if (cancellation?.cancelled) return Promise.reject(new HttpError(HttpErrorCode.Cancelled));
    let task: http.HttpRequest;
    try { task = http.createHttp(); }
    catch { return Promise.reject(new HttpError(HttpErrorCode.Network)); }
    return new Promise<HttpResponse>((resolve, reject) => {
      let settled = false;
      let unsubscribe: () => void = () => {};
      const finish = (error?: HttpError, response?: HttpResponse): void => {
        if (settled) return;
        settled = true;
        unsubscribe();
        try { task.destroy(); } catch { /* Cleanup must not replace the original outcome. */ }
        if (error) reject(error);
        else if (response) resolve(response);
        else reject(new HttpError(HttpErrorCode.InvalidResponse));
      };
      if (cancellation) unsubscribe = cancellation.subscribe(() => finish(new HttpError(HttpErrorCode.Cancelled)));
      if (settled) return;
      const options: http.HttpRequestOptions = {
        method: this.method(request.method), header: request.headers, extraData: request.body,
        expectDataType: request.responseType === HttpResponseType.Binary ? http.HttpDataType.ARRAY_BUFFER : http.HttpDataType.STRING,
        usingCache: false, connectTimeout: request.connectTimeoutMs, readTimeout: request.readTimeoutMs,
        maxLimit: request.maxResponseBytes
      };
      try {
        task.request(request.url, options).then((result: http.HttpResponse) => {
          const valid = request.responseType === HttpResponseType.Binary ? result.result instanceof ArrayBuffer :
            typeof result.result === 'string';
          if (!valid) {
            finish(new HttpError(HttpErrorCode.InvalidResponse));
          } else {
            finish(undefined, new HttpResponse(result.responseCode, result.result as HttpBody,
              result.header as HttpResponseHeaders, result.cookies));
          }
        }).catch((error: BusinessError) => finish(this.failure(error)));
      } catch (error) { finish(this.failure(error as BusinessError)); }
    });
  }

  private failure(error: BusinessError): HttpError {
    const code = typeof error?.code === 'number' ? error.code : 0;
    return new HttpError(code === 2300028 ? HttpErrorCode.Timeout : HttpErrorCode.Network, 0, code);
  }

  private method(method: HttpMethod): http.RequestMethod {
    switch (method) {
      case HttpMethod.POST: return http.RequestMethod.POST;
      case HttpMethod.PUT: return http.RequestMethod.PUT;
      case HttpMethod.DELETE: return http.RequestMethod.DELETE;
      case HttpMethod.HEAD: return http.RequestMethod.HEAD;
      default: return http.RequestMethod.GET;
    }
  }
}
