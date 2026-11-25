@Component
export struct ReaderIcon {
  @Prop name: string = 'search';
  @Prop active: boolean = false;
  @Prop iconSize: number = 22;

  build() {
    Image($rawfile(`icons/${this.name}${this.active ? '-active' : ''}.svg`))
      .width(this.iconSize)
      .height(this.iconSize)
      .objectFit(ImageFit.Contain)
      .draggable(false)
      .accessibilityLevel('no')
  }
}
