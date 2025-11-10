//
//  CursorStyle.swift
//  mouse-fun
//
//  Created by liliang on 2025/11/7.
//

import Foundation

enum CursorStyle: String, CaseIterable, Identifiable {
    case defaultCursor = "Default"
    case heart = "Heart"
    case star = "Star"
    case rocket = "Rocket"
    case moon = "Moon"
    case diamond = "Diamond"
    case wand = "Wand"
    case feather = "Feather"
    case coffee = "Coffee"
    case icecream = "Ice Cream"
    case banana = "Banana"
    case customEmoji = "Custom Emoji..."

    var id: String { rawValue }

    var svgFileName: String? {
        switch self {
        case .heart: return "cursor-heart"
        case .star: return "cursor-star"
        case .rocket: return "cursor-rocket"
        case .moon: return "cursor-moon"
        case .diamond: return "cursor-diamond"
        case .wand: return "cursor-wand"
        case .feather: return "cursor-feather"
        case .coffee: return "cursor-coffee"
        case .icecream: return "cursor-icecream"
        case .banana: return "cursor-banana"
        default: return nil
        }
    }

    var displayName: String {
        rawValue
    }
}
