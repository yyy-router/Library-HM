export class CancellationToken {
  private stopped: boolean = false;
  private listeners: (() => void)[] = [];

  get cancelled(): boolean { return this.stopped; }

  cancel(): void {
    if (this.stopped) return;
    this.stopped = true;
    const listeners = this.listeners;
    this.listeners = [];
    listeners.forEach((listener: () => void) => {
      try { listener(); } catch { /* One listener must not prevent the others from being notified. */ }
    });
  }

  subscribe(listener: () => void): () => void {
    if (this.stopped) {
      listener();
      return () => {};
    }
    this.listeners.push(listener);
    return () => { this.listeners = this.listeners.filter((item: () => void) => item !== listener); };
  }
}
