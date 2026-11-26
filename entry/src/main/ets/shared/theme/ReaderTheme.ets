// 保留资源引用，让系统在亮色/深色模式切换时重新解析颜色。
export class ReaderTheme {
  static readonly BLUE: Resource = $r('app.color.brand_primary');
  static readonly BLUE_TINT: Resource = $r('app.color.demo_background');
  static readonly INK: Resource = $r('app.color.text_primary');
  static readonly SECONDARY: Resource = $r('app.color.text_secondary');
  static readonly MUTED: Resource = $r('app.color.text_muted');
  static readonly LINE: Resource = $r('app.color.divider');
  static readonly BACKGROUND: Resource = $r('app.color.app_background');
  static readonly SURFACE: Resource = $r('app.color.surface');
  static readonly SUBTLE: Resource = $r('app.color.surface_subtle');
  static readonly ON_ACCENT: Resource = $r('app.color.on_accent');
  static readonly INPUT_BORDER: Resource = $r('app.color.input_border');
  static readonly TRACK: Resource = $r('app.color.progress_track');
  static readonly SHADOW: Resource = $r('app.color.card_shadow');
  static readonly SHELF_TOP: Resource = $r('app.color.shelf_top');
  static readonly SHELF_MIDDLE: Resource = $r('app.color.shelf_middle');
  static readonly SHELF_BOTTOM: Resource = $r('app.color.shelf_bottom');
}
