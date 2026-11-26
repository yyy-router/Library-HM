import { hvigor } from '@ohos/hvigor';
import { appTasks, OhosAppContext, OhosPluginId } from '@ohos/hvigor-ohos-plugin';
import { applyLocalSigning } from './hvigor/local-signing.cjs';

// Apply credentials only to the in-memory build context, never to the shared file.
hvigor.getRootNode().afterNodeEvaluate(node => {
  const context = node.getContext(OhosPluginId.OHOS_APP_PLUGIN) as OhosAppContext;
  context.setBuildProfileOpt(applyLocalSigning(context.getBuildProfileOpt(), __dirname));
});

export default {
  system: appTasks,
  plugins: []
};
