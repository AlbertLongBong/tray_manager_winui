# tray_manager_winui – Ideen für zukünftige Optionen

Übersicht möglicher Erweiterungen für das Plugin. Keine Prioritäten – nur eine Sammlung implementierbarer Optionen.

---

## Styling (WinUIContextMenuStyle)

| Option | Beschreibung | Aufwand |
|--------|--------------|---------|
| ~~`borderColor` / `borderThickness`~~ | ~~Rahmen um das Menü~~ | ✅ Implementiert |
| ~~`shadowElevation`~~ | ~~Schatten-Effekt~~ | ✅ Implementiert |
| ~~`itemHeight` / `minItemHeight`~~ | ~~Mindesthöhe pro Menüeintrag~~ | ✅ Implementiert |
| `checkedForegroundColor` / `checkedBackgroundColor` | Styling für Checkbox im gecheckten Zustand | Mittel – ToggleMenuFlyoutItem Resource-Keys |
| `iconColor` | Farbe für Icons (vorbereitend für Phase 2) | Gering |
| ~~`fontStyle`~~ | ~~Kursiv/Normal~~ | ✅ Implementiert |
| `keyboardAcceleratorColor` | Farbe für Tastenkürzel (z.B. „Ctrl+C“) | Mittel – Resource-Keys in WinUI |

---

## Menü-Items (MenuItem-API)

| Option | Beschreibung | Abhängigkeit |
|--------|--------------|--------------|
| **Icons** | `MenuItem(icon: 'path/to/icon.ico')` – WinUI MenuFlyoutItem.Icon | Phase 2, ggf. menu_base erweitern |
| **accelerator** | `MenuItem(accelerator: 'Ctrl+C')` – Text rechts neben dem Label | menu_base erweitern, WinUI KeyboardAcceleratorTextOverride |
| **tooltip** | `MenuItem(tooltip: 'Längere Beschreibung')` | menu_base + WinUI ToolTipService.SetToolTip |

---

## Menü-Verhalten (API-Erweiterungen)

| Option | Beschreibung | Aufwand |
|--------|--------------|---------|
| ~~`showContextMenuAt(x, y)`~~ | ~~Menü an expliziter Position statt Cursor~~ | ✅ Implementiert (x, y als optionale Parameter von showContextMenu) |
| ~~`placement`~~ | ~~Wo das Menü relativ zum Anker erscheint (Top/Bottom/Left/Right)~~ | ✅ Implementiert (Parameter von showContextMenu, WinUIFlyoutPlacement) |
| `inputDevicePrefersRightSide` | Menü rechts vom Cursor für Linkshänder | Nicht verfügbar – API existiert in WinUI 3 nicht (nur InputDevicePrefersPrimaryCommands, read-only) |

---

## Weitere native WinUI-Optionen

| Option | Beschreibung |
|--------|--------------|
| `maxHeight` | Maximale Menühöhe mit Scrollbar |
| `exclusionRect` | Bereiche, die das Menü vermeiden soll (z.B. Taskleiste) |

---

## Priorisierung (optional)

**Schnell umsetzbar:** ~~borderColor/borderThickness~~, ~~fontStyle~~, ~~showContextMenuAt(x,y)~~, ~~itemHeight~~ (implementiert). inputDevicePrefersRightSide: nicht in WinUI 3 API.  

**Hoher Nutzen:** Icons (Phase 2), accelerator (Tastenkürzel), ~~placement~~ (implementiert)  

**Nice-to-have:** ~~Schatten~~ (implementiert), Checkbox-Styling, Tooltip
