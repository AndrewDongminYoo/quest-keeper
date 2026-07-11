//
//  PixelSprite.swift
//  QuestKeeper
//
//  DESIGN.md Adoption step 5 — real pixel sprites for the hero and monsters, drawn in code
//  instead of bundled PNG assets. Rationale (first rendering-layer decision in the repo, so it
//  sets precedent): the project's point is building on 1st-party stacks by hand with no asset
//  pipeline. `Canvas` (a 1st-party primitive, like the already-used `TimelineView`) renders a
//  compact ASCII bitmap as a crisp pixel grid, and stays theme-aware because palette `Color`s
//  resolve to the current appearance.
//
//  Shape carries monster identity; color carries the *derived* mob tier (passed in at render time
//  from `MobVisual.tint`, never baked into the bitmap) — same spirit as "persist facts, derive state".
//

import SwiftUI

/// Renders an ASCII bitmap (`rows`) as a centered pixel grid. Each character maps to a color via
/// `palette`; characters absent from the palette (conventionally ".") are left transparent.
struct PixelSprite: View {
    let rows: [String]
    let palette: [Character: Color]

    var body: some View {
        Canvas { context, size in
            let columns = rows.map(\.count).max() ?? 0
            guard columns > 0, !rows.isEmpty else { return }

            let cell = min(size.width / CGFloat(columns), size.height / CGFloat(rows.count))
            let originX = (size.width - cell * CGFloat(columns)) / 2
            let originY = (size.height - cell * CGFloat(rows.count)) / 2

            for (y, row) in rows.enumerated() {
                for (x, character) in row.enumerated() {
                    guard let color = palette[character] else { continue }
                    let rect = CGRect(
                        x: originX + CGFloat(x) * cell,
                        y: originY + CGFloat(y) * cell,
                        // Half-pixel overlap hides hairline seams between adjacent cells.
                        width: cell + 0.5,
                        height: cell + 0.5
                    )
                    context.fill(Path(rect), with: .color(color))
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// The dungeon's pixel-art bitmaps. `#` is the body (the injected tier/hero color), `o` is a
/// `stone`-colored hole (eyes/sockets), `.` is empty. Kept shape-only so color stays derived.
enum DungeonSprites {
    /// A little front-facing adventurer. Reused for the mourning state (grave-tinted, rotated).
    static let hero = [
        "..#####..",
        ".#######.",
        ".#o###o#.",
        ".#######.",
        "..#####..",
        "...###...",
        "..#####..",
        ".#######.",
        "#.#####.#",
        "...#.#...",
        "..##.##.."
    ]

    /// mobLevel 0–1 — a dome blob with a drippy base.
    static let slime = [
        "...####...",
        "..######..",
        ".########.",
        ".##o##o##.",
        "##########",
        "##########",
        ".########.",
        "##.####.##"
    ]

    /// mobLevel 2–3 — a skull: rounded cranium, two sockets, a notched-teeth jaw, solid chin.
    static let skeleton = [
        "..######..",
        ".########.",
        "##########",
        "#oo####oo#",
        "#oo####oo#",
        ".########.",
        ".#o#o#o#..",
        "..######.."
    ]

    /// mobLevel 4–5 — a horned head with wide eyes, nostrils, and teeth.
    static let dragon = [
        "#..####..#",
        ".########.",
        "##########",
        "#o######o#",
        "##########",
        "###o##o###",
        ".########.",
        "..#.##.#.."
    ]

    /// The monster bitmap for a derived mob level. Visual only — mirrors `MobVisual.tint`'s tiers.
    static func monster(level: Int) -> [String] {
        switch level {
        case ..<2: slime
        case 2..<4: skeleton
        default: dragon
        }
    }
}
