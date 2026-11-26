import { ConfigurationConstant, UIAbility } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';

export default class EntryAbility extends UIAbility {
  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index').then(() => {
      // 按 SDK 要求在窗口与页面加载后设置，随后跟随系统切换。
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    }).catch((error: BusinessError) => {
      hilog.error(0x0000, 'LibraryHM', 'Page setup failed: %{public}d', error.code);
    });
  }
}
