# Shop Upgrade Badge Legend

Shop upgrade cards surface a small badge next to the title so players can read an upgrade's role at a glance. Each badge is keyed off the upgrade's tag list: the shop looks up the first matching tag in its badge dictionary and renders the associated shape and color, falling back to a default pill when no specific match exists.

## Badge Mapping

| Tag | Badge Shape | Theme Color Key | Fallback RGBA |
| --- | --- | --- | --- |
| default | Circle | — | `0.66, 0.72, 0.90, 1` |
| economy | Circle | `Theme.goldenPearColor` | `0.95, 0.80, 0.45, 1` |
| defense | Diamond | `Theme.snakeDefault` | `0.45, 0.85, 0.70, 1` |
| mobility | Upward triangle | `Theme.blueberryColor` | `0.55, 0.65, 0.95, 1` |
| risk | Downward triangle | `Theme.warningColor` | `0.92, 0.55, 0.40, 1` |
| utility | Rounded square | `Theme.panelBorder` | `0.32, 0.50, 0.54, 1` |
| hazard | Hexagon | `Theme.appleColor` | `0.90, 0.45, 0.55, 1` |
| adrenaline | Pentagon | `Theme.dragonfruitColor` | `0.90, 0.60, 0.80, 1` |
| speed | Capsule | `Theme.buttonHover` | `0.34, 0.30, 0.48, 1` |
| rocks | Hexagon | `Theme.rock` | `0.30, 0.30, 0.35, 1` |
| shop | Circle | `Theme.borderColor` | `0.42, 0.72, 0.62, 1` |
| progression | Diamond | `Theme.progressColor` | `0.55, 0.75, 0.55, 1` |
| reward | Circle | `Theme.accentTextColor` | `0.82, 0.92, 0.78, 1` |
| combo | Rounded square | `Theme.achieveColor` | `0.80, 0.45, 0.65, 1` |

*Badge shapes are rendered by dedicated drawing helpers that map abstract names like `triangle_up` or `capsule` to Love2D primitives, ensuring consistent silhouettes and rounding across the interface.*

### Notes

* All badge colors pull from the active theme when possible, falling back to the RGBA tints listed above whenever a theme omits a swatch.
* Upgrades that declare multiple tags use the first tag with a registered badge; if none of the tags are recognized, the default circle badge is used.
