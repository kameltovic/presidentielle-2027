// Icône Élysée 2027 : une urne stylisée bleu → rouge avec « 27 ».
// Usage : swift tools/icon.swift Elysee/Assets.xcassets/AppIcon.appiconset/icon.png
import AppKit
import SwiftUI

struct Icon: View {
    let bleu = Color(red: 0.13, green: 0.25, blue: 0.72)
    let rouge = Color(red: 0.90, green: 0.24, blue: 0.27)

    var body: some View {
        ZStack {
            LinearGradient(colors: [bleu, Color(red: 0.42, green: 0.22, blue: 0.62), rouge], startPoint: .topLeading, endPoint: .bottomTrailing)
            // Bulletin qui glisse dans la fente.
            RoundedRectangle(cornerRadius: 22).fill(.white.opacity(0.95))
                .frame(width: 300, height: 220)
                .rotationEffect(.degrees(-8))
                .offset(y: -250)
                .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
            // Urne.
            RoundedRectangle(cornerRadius: 70, style: .continuous).fill(.white.opacity(0.18))
                .overlay(RoundedRectangle(cornerRadius: 70, style: .continuous).stroke(.white.opacity(0.55), lineWidth: 10))
                .frame(width: 620, height: 520)
                .offset(y: 110)
            Capsule().fill(.black.opacity(0.35)).frame(width: 340, height: 30).offset(y: -140)
            Text("27")
                .font(.system(size: 330, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .offset(y: 140)
        }
        .frame(width: 1024, height: 1024)
    }
}

@MainActor func render() {
    let renderer = ImageRenderer(content: Icon())
    renderer.scale = 1
    let cg = renderer.cgImage!
    let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])!
    try! png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
}
MainActor.assumeIsolated { render() }
