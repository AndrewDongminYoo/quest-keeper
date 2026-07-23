//
//  DungeonStyle.swift
//  QuestKeeper
//
//  App-target-only styling built on the shared palette. Kept out of QuestKeeperShared because
//  `DungeonUrgencyTone` lives in the app's derivation-presentation layer and the widget doesn't
//  need the button style — only `DungeonPalette`/`MobVisual`/`PixelStyle`/`PixelSprite` are shared.
//

import SwiftUI

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

/// A flat, chunky, square-bordered action button — the pixel-dungeon counterpart to the
/// system `.borderedProminent` (whose soft capsule reads as native-iOS, not game).
struct PixelButtonStyle: ButtonStyle {
    var fill: Color = DungeonPalette.hero
    var foreground: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.footnote.weight(.black))
            .foregroundStyle(foreground)
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
