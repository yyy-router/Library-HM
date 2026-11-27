export interface SessionVault {
  read(): Promise<string | undefined>;
  write(value: string): Promise<void>;
  clear(): Promise<void>;
}

// Used by isolated logic tests; native composition always injects the system vault.
export class MemorySessionVault implements SessionVault {
  private value: string | undefined = undefined;
  async read(): Promise<string | undefined> { return this.value; }
  async write(value: string): Promise<void> { this.value = value; }
  async clear(): Promise<void> { this.value = undefined; }
}
