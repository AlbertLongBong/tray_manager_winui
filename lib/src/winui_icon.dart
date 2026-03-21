/// Icon types for WinUI 3 menu items.
///
/// Use [WinUIIcon.glyph] for custom Segoe Fluent Icons / MDL2 Assets codepoints,
/// or [WinUIIcon.symbol] for common pre-defined symbols.
///
/// Example:
/// ```dart
/// WinUIMenuItem(
///   label: 'Copy',
///   winuiIcon: WinUIIcon.symbol(WinUISymbol.copy),
/// )
/// ```
sealed class WinUIIcon {
  const WinUIIcon();

  /// Creates a [FontIcon] from a glyph codepoint.
  ///
  /// [codePoint] is the Unicode codepoint (e.g. `0xE8C8` for Copy).
  /// [fontFamily] overrides the default font ("Segoe Fluent Icons" on Win11,
  /// "Segoe MDL2 Assets" on Win10). Leave null for the system default.
  const factory WinUIIcon.glyph(
    int codePoint, {
    String? fontFamily,
  }) = WinUIGlyphIcon;

  /// Creates a [FontIcon] from a well-known [WinUISymbol].
  ///
  /// Convenience wrapper that maps the symbol to its glyph codepoint.
  factory WinUIIcon.symbol(WinUISymbol symbol) =>
      WinUIGlyphIcon(symbol.codePoint);

  /// Serializes this icon as a hex string for the method channel.
  ///
  /// Format: `"0xHHHH"` — parsed on the native side to create a FontIcon.
  String toIconString();
}

/// A [WinUIIcon] backed by a glyph codepoint.
class WinUIGlyphIcon extends WinUIIcon {
  const WinUIGlyphIcon(this.codePoint, {this.fontFamily});

  /// Unicode codepoint for the glyph (e.g. `0xE8C8`).
  final int codePoint;

  /// Optional font family override. When null, uses the platform default
  /// (Segoe Fluent Icons on Windows 11, Segoe MDL2 Assets on Windows 10).
  final String? fontFamily;

  @override
  String toIconString() =>
      '0x${codePoint.toRadixString(16).toUpperCase().padLeft(4, '0')}';
}

/// Pre-defined symbols mapping to Segoe Fluent Icons / MDL2 Assets glyphs.
///
/// See [Segoe Fluent Icons font](https://learn.microsoft.com/en-us/windows/apps/design/style/segoe-fluent-icons-font)
/// for the full glyph reference.
enum WinUISymbol {
  accept(0xE8FB),
  add(0xE710),
  back(0xE72B),
  calendar(0xE787),
  camera(0xE722),
  cancel(0xE711),
  clear(0xE894),
  clock(0xE823),
  closedCaption(0xE7F0),
  closePane(0xE89F),
  contact(0xE77B),
  copy(0xE8C8),
  crop(0xE7A8),
  cut(0xE8C6),
  deleteIcon(0xE74D),
  document(0xE8A5),
  download(0xE896),
  edit(0xE70F),
  emoji(0xE899),
  favorite(0xE734),
  filter(0xE71C),
  find(0xE721),
  flag(0xE7C1),
  folder(0xE8B7),
  font(0xE8D2),
  forward(0xE72A),
  globe(0xE774),
  help(0xE897),
  home(0xE80F),
  important(0xE8C9),
  italic(0xE8DB),
  keyboard(0xE765),
  library(0xE8F1),
  link(0xE71B),
  list(0xEA37),
  mail(0xE715),
  manage(0xE912),
  mapPin(0xE707),
  more(0xE712),
  mute(0xE74F),
  newFolder(0xE8F4),
  newWindow(0xE78B),
  openFile(0xE8E5),
  openPane(0xE8A0),
  openWith(0xE7AC),
  paste(0xE77F),
  pause(0xE769),
  people(0xE716),
  permissions(0xE8D7),
  phone(0xE717),
  pin(0xE718),
  play(0xE768),
  print(0xE749),
  redo(0xE7A6),
  refresh(0xE72C),
  remove(0xE738),
  rename(0xE8AC),
  repair(0xE90F),
  rotate(0xE7AD),
  save(0xE74E),
  scan(0xE8FE),
  send(0xE724),
  setting(0xE713),
  share(0xE72D),
  shop(0xE719),
  sort(0xE8CB),
  stop(0xE71A),
  switchApp(0xE8AB),
  sync(0xE895),
  tag(0xE8EC),
  undo(0xE7A7),
  unpin(0xE77A),
  upload(0xE898),
  video(0xE714),
  volume(0xE767),
  webcam(0xE8B8),
  world(0xE909),
  zoom(0xE71E),
  zoomIn(0xE8A3),
  zoomOut(0xE71F),
  ;

  const WinUISymbol(this.codePoint);

  /// The Segoe Fluent Icons / MDL2 Assets glyph codepoint.
  final int codePoint;
}
