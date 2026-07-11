//
//  DungeonPalette.swift
//  QuestKeeper
//
//  DESIGN.md semantic color tokens — the single source for every dungeon color.
//  Each token is backed by an asset-catalog color set carrying light + dark values,
//  so tokens flip with the system appearance. Accent tokens carry meaning only
//  (DESIGN.md "Accent colors carry meaning only"); do not use them decoratively.
//

import SwiftUI

/// The DESIGN.md palette. Names match the color sets in `Assets.xcassets`.
///
/// Light `dungeon`/`stone` deviate from the DESIGN.md table on purpose: the table's
/// light surfaces are near-black, which drops `ink` text below 1.3:1 in light appearance.
/// They are remapped to real light surfaces (see DESIGN.md note) so light mode stays legible.
enum DungeonPalette {
    /// Primary text.
    static let ink = Color("ink")
    /// Main background.
    static let dungeon = Color("dungeon")
    /// Floor tiles / elevated surfaces (rows, panels).
    static let stone = Color("stone")
    /// Warm dungeon light — used for the mid ("warning") urgency step.
    static let torch = Color("torch")
    /// Hero / primary action (create, complete, retry).
    static let hero = Color("hero")
    /// Coins, stars, completed / victory state.
    static let victory = Color("victory")
    /// Urgency and high-level monsters.
    static let danger = Color("danger")
    /// Today's missed-quest (grave) marker.
    static let grave = Color("grave")
    /// Elder guide / safe advice. Reserved for the guide surface — not for generic "calm" states.
    static let guide = Color("guide")
}

extension DungeonUrgencyTone {
    /// Urgency tint. Calm carries **no accent** — a muted `ink` — so `torch`/`danger` stay meaningful
    /// as urgency climbs and the board is not flooded with accent color at rest.
    var tint: Color {
        switch self {
        case .calm: DungeonPalette.ink.opacity(0.45)
        case .warning: DungeonPalette.torch
        case .danger: DungeonPalette.danger
        }
    }
}

/// Visual tint for a derived mob level. Mirrors the urgency ramp: low mobs are neutral,
/// accent appears only for stronger monsters. Visual only — never stored on `Quest`.
enum MobVisual {
    static func tint(level: Int) -> Color {
        switch level {
        case ..<2: DungeonPalette.ink.opacity(0.45)
        case 2..<4: DungeonPalette.torch
        default: DungeonPalette.danger
        }
    }
}

/// Shared pixel geometry — square-ish chunky corners instead of soft iOS rounding.
enum PixelStyle {
    static let corner: CGFloat = 2
    static let border: CGFloat = 2
}

/// A flat, chunky, square-bordered action button — the pixel-dungeon counterpart to the
/// system `.borderedProminent` (whose soft capsule reads as native-iOS, not game).
struct PixelButtonStyle: ButtonStyle {
    var fill: Color = DungeonPalette.hero

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.footnote.weight(.black))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(fill, in: RoundedRectangle(cornerRadius: PixelStyle.corner))
            .overlay(
                RoundedRectangle(cornerRadius: PixelStyle.corner)
                    .stroke(DungeonPalette.ink.opacity(0.25), lineWidth: PixelStyle.border)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

extension ButtonStyle where Self == PixelButtonStyle {
    static var pixel: PixelButtonStyle { PixelButtonStyle() }
}
