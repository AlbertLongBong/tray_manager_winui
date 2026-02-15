/// Placement of the context menu relative to its anchor (cursor or x,y).
///
/// Maps to WinUI [FlyoutPlacementMode](https://learn.microsoft.com/en-us/windows/windows-app-sdk/api/winrt/microsoft.ui.xaml.controls.primitives.flyoutplacementmode).
/// Use with [TrayManagerWinUI.showContextMenu].
enum WinUIFlyoutPlacement {
  /// Menu above the anchor.
  top,

  /// Menu below the anchor.
  bottom,

  /// Menu to the left of the anchor.
  left,

  /// Menu to the right of the anchor.
  right,

  /// Menu centered on screen.
  full,

  /// Placement determined automatically by WinUI.
  auto,

  /// Above anchor, left edge aligned.
  topEdgeAlignedLeft,

  /// Above anchor, right edge aligned.
  topEdgeAlignedRight,

  /// Below anchor, left edge aligned.
  bottomEdgeAlignedLeft,

  /// Below anchor, right edge aligned.
  bottomEdgeAlignedRight,

  /// Left of anchor, top edge aligned.
  leftEdgeAlignedTop,

  /// Left of anchor, bottom edge aligned.
  leftEdgeAlignedBottom,

  /// Right of anchor, top edge aligned.
  rightEdgeAlignedTop,

  /// Right of anchor, bottom edge aligned.
  rightEdgeAlignedBottom,
}
