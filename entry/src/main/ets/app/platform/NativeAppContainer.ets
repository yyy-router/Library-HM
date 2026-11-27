import { AppContainer } from '../AppContainer';
import { HarmonyHttpTransport } from '../../platform/network/HarmonyHttpTransport';
import { AssetSessionVault } from '../../platform/security/AssetSessionVault';
import { AppConfig } from '../../core/config/AppConfig';

export const appContainer: AppContainer = new AppContainer(new HarmonyHttpTransport(), AppConfig.API_BASE_URL,
  new AssetSessionVault());
