import { util } from '@kit.ArkTS';
import { ImageSourceEncoder } from '../../domain/service/CoverImageRepository';

export class HarmonyImageSourceEncoder implements ImageSourceEncoder {
  encode(bytes: Uint8Array, mime: string): string {
    return `data:${mime};base64,${new util.Base64Helper().encodeToStringSync(bytes)}`;
  }
}
