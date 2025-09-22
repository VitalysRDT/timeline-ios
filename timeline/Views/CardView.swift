//
//  CardView.swift
//  timeline
//
//  Created by Vitalys ROUGETET--DE TROYANE on 17/09/2025.
//

import SwiftUI

struct CardView: View {
    let card: Card
    let isRevealed: Bool
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: isRevealed ? 
                            [Color(hex: card.category.color) ?? .blue, Color(hex: card.category.color)?.opacity(0.8) ?? .blue.opacity(0.8)] :
                            [Color.gray.opacity(0.7), Color.gray.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(radius: 4)
            
            VStack(spacing: 4) {
                if isRevealed {
                    Text(card.title)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    
                    Text(card.formattedDate)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white.opacity(0.9))
                    
                    Text(card.category.rawValue)
                        .font(.system(size: 8))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.white.opacity(0.2))
                        .clipShape(Capsule())
                } else {
                    Image(systemName: "questionmark")
                        .font(.title2)
                        .foregroundColor(.white)
                }
            }
            .padding(8)
        }
    }
}

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }
        
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        
        self.init(red: r, green: g, blue: b)
    }
}