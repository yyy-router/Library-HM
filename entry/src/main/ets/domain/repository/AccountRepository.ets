import { AccountSession } from '../model/AccountSession';

export interface AccountRepository {
  getSession(): Promise<AccountSession | undefined>;
  signIn(email: string, password: string): Promise<AccountSession>;
  signOut(): Promise<void>;
}
