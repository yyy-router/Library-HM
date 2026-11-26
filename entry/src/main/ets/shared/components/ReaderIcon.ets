@Component
export struct ReaderIcon {
  @Prop name: string = 'search';
  @Prop active: boolean = false;
  @Prop iconSize: number = 22;

  private source(): Resource {
    if (this.name === 'home') return this.active ? $r('app.media.ic_home_active') : $r('app.media.ic_home');
    if (this.name === 'shelf') return this.active ? $r('app.media.ic_shelf_active') : $r('app.media.ic_shelf');
    if (this.name === 'user') return $r('app.media.ic_user_active');
    if (this.name === 'bookmark') return $r('app.media.ic_bookmark_active');
    if (this.name === 'plus') return $r('app.media.ic_plus');
    if (this.name === 'close') return $r('app.media.ic_close');
    if (this.name === 'chevron') return $r('app.media.ic_chevron');
    return $r('app.media.ic_search');
  }

  build() {
    Image(this.source())
      .width(this.iconSize)
      .height(this.iconSize)
      .objectFit(ImageFit.Contain)
      .draggable(false)
      .accessibilityLevel('no')
  }
}
