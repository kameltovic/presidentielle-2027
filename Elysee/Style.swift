import SwiftUI

extension Font {
    /// Voix d'affichage, comme Onde : SF Pro élargie et grasse.
    static func display(_ style: Font.TextStyle, _ weight: Font.Weight = .bold) -> Font {
        .system(style, weight: weight).width(.expanded)
    }
}

/// Drapeau tricolore dessiné (couleurs officielles du drapeau) — pas le logo Marianne, réservé aux services de l'État.
struct Tricolore: View {
    var height: CGFloat = 24

    var body: some View {
        HStack(spacing: 0) {
            Color(red: 0, green: 0, blue: 0.57)      // #000091
            Color.white
            Color(red: 0.88, green: 0, blue: 0.06)   // #E1000F
        }
        .frame(width: height * 1.5, height: height)
        .clipShape(.rect(cornerRadius: height * 0.18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: height * 0.18, style: .continuous).strokeBorder(.primary.opacity(0.15)))
        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
        .accessibilityHidden(true)
    }
}

/// Surtitre en capitales espacées (« JEUDI 8 OCTOBRE »).
struct Eyebrow: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased()).font(.caption.weight(.semibold)).tracking(1.4).opacity(0.6)
    }
}

// MARK: - Couleurs

/// Couleur sRGB manipulable : luminance relative (WCAG) et mélanges, pour garantir le contraste.
struct RGB: Equatable {
    var r, g, b: Double

    init(r: Double, g: Double, b: Double) { (self.r, self.g, self.b) = (r, g, b) }
    init(hex: String) {
        var h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        if h.count == 3 { h = h.map { "\($0)\($0)" }.joined() }
        let v = UInt64(h, radix: 16) ?? 0x888888
        self.init(r: Double((v >> 16) & 0xFF) / 255, g: Double((v >> 8) & 0xFF) / 255, b: Double(v & 0xFF) / 255)
    }

    static let white = RGB(r: 1, g: 1, b: 1)
    static let black = RGB(r: 0, g: 0, b: 0)

    var luminance: Double {
        func lin(_ c: Double) -> Double { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
    }

    func mixed(with o: RGB, by t: Double) -> RGB { RGB(r: r + (o.r - r) * t, g: g + (o.g - g) * t, b: b + (o.b - b) * t) }

    /// Éclaircit (ou assombrit) par petits pas jusqu'à passer le seuil de luminance.
    func until(_ ok: (Double) -> Bool, towards o: RGB) -> RGB {
        var c = self
        for _ in 0..<12 where !ok(c.luminance) { c = c.mixed(with: o, by: 0.12) }
        return c
    }

    var color: Color { Color(red: r, green: g, blue: b) }
}

extension Color {
    static let bleu = Color(red: 0.15, green: 0.27, blue: 0.75)
    static let rouge = Color(red: 0.90, green: 0.25, blue: 0.27)
    static let ink = Color(red: 0.035, green: 0.035, blue: 0.05)
    /// Fond de l'app : encre en sombre, papier chaud en clair.
    static let canvas = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.035, green: 0.035, blue: 0.05, alpha: 1)
        : UIColor(red: 0.965, green: 0.958, blue: 0.945, alpha: 1) })
}

extension Candidate {
    private var rgb: RGB { partyColor.map(RGB.init(hex:)) ?? RGB(r: 0.55, g: 0.55, b: 0.58) }
    /// Couleur brute du parti (modèle Wikipédia) : pour les aplats et l'aura.
    var color: Color { rgb.color }
    /// Version sombre pour les fonds de légende : le texte blanc reste lisible même sur le jaune (contraste ≥ 4,5).
    var deep: Color { rgb.until({ $0 <= 0.12 }, towards: .black).mixed(with: .black, by: 0.25).color }
    /// Couleur d'accent lisible sur le fond : éclaircie en sombre (fini le bleu sur bleu), assombrie en clair.
    func accent(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? rgb.until({ $0 >= 0.30 }, towards: .white).color
            : rgb.until({ $0 <= 0.16 }, towards: .black).color
    }
}

// MARK: - Fonds

/// Fond de l'app avec une aura colorée en haut (couleur du parti, ou bleu / rouge par défaut).
struct Backdrop: View {
    var color: Color?

    var body: some View {
        ZStack(alignment: .top) {
            Color.canvas
            Aura(colors: Aura.palette(color), dim: 0.45)
                .frame(height: 640)
                .mask(LinearGradient(colors: [.black, .black.opacity(0.6), .clear], startPoint: .top, endPoint: .bottom))
        }
        .ignoresSafeArea()
    }
}

/// Dégradé maillé qui dérive lentement (même effet que la page d'accueil d'Onde).
struct Aura: View {
    let colors: [Color]
    var dim: Double = 0.35
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { ctx in
            let t = Float(ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 10_000))
            MeshGradient(width: 3, height: 3, points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.5 + 0.12 * sin(t * 0.31)], [0.5 + 0.18 * sin(t * 0.23), 0.5 + 0.18 * cos(t * 0.19)], [1, 0.5 + 0.12 * cos(t * 0.27)],
                [0, 1], [0.5, 1], [1, 1],
            ], colors: colors)
        }
        .overlay(Color.canvas.opacity(dim))
        .animation(.easeInOut(duration: 1.2), value: colors)
        .ignoresSafeArea()
    }

    /// Neuf teintes dérivées d'une couleur ; sans couleur : bleu, violet, rouge.
    static func palette(_ c: Color?) -> [Color] {
        let base = Color.canvas
        guard let c else {
            return [.bleu, .bleu.mix(with: .rouge, by: 0.5), .rouge, .bleu.mix(with: base, by: 0.5), base, .rouge.mix(with: base, by: 0.5), base, base, base]
        }
        return [c, c.mix(with: base, by: 0.35), c.mix(with: .white, by: 0.15),
                c.mix(with: base, by: 0.55), c.mix(with: base, by: 0.2), c.mix(with: base, by: 0.7),
                base, c.mix(with: base, by: 0.6), base]
    }
}

// MARK: - Composants

/// Carte en verre avec titre optionnel (même carte que Skyzen, Grandir, Onde).
struct Card<Content: View>: View {
    var title: String?
    var systemImage: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let title {
                HStack(spacing: 10) {
                    if let systemImage {
                        Image(systemName: systemImage)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.tint)
                            .frame(width: 30, height: 30)
                            .background(.tint.opacity(0.16), in: .rect(cornerRadius: 9, style: .continuous))
                    }
                    Text(title).font(.display(.headline))
                }
                .accessibilityAddTraits(.isHeader)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassEffect(.regular, in: .rect(cornerRadius: 28, style: .continuous))
    }
}

/// Image distante remplie dans son cadre, avec un fond neutre pendant le chargement.
struct Remote: View {
    let url: URL?
    var fit = false

    var body: some View {
        AsyncImage(url: url, transaction: .init(animation: .easeOut(duration: 0.2))) { phase in
            if let image = phase.image {
                if fit { image.resizable().scaledToFit() } else { image.resizable().scaledToFill() }
            } else {
                Rectangle().fill(.primary.opacity(0.06))
            }
        }
        .accessibilityHidden(true)
    }
}

struct Avatar: View {
    let candidate: Candidate
    var size: CGFloat = 56

    var body: some View {
        Group {
            if let photo = candidate.photo {
                AsyncImage(url: photo.url) { $0.resizable().scaledToFill() } placeholder: { initials }
            } else {
                initials
            }
        }
        .frame(width: size, height: size, alignment: .top)
        .clipShape(.circle)
        .accessibilityHidden(true)
    }

    private var initials: some View {
        Circle().fill(.primary.opacity(0.08)).overlay(Text(candidate.initials).font(.display(size > 80 ? .title : .caption)).foregroundStyle(.secondary))
    }
}

/// Logo du parti en silhouette blanche (pas de fond blanc). Les JPG, opaques, donneraient un carré blanc : on les ignore.
struct PartyMark: View {
    let candidate: Candidate
    var size: CGFloat = 18

    var body: some View {
        if let logo = candidate.partyLogo, !logo.file.lowercased().hasSuffix(".jpg"), !logo.file.lowercased().hasSuffix(".jpeg") {
            AsyncImage(url: logo.url) { $0.resizable().scaledToFit().brightness(1) } placeholder: { Color.clear }
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        }
    }
}

/// Pastille du parti : silhouette du logo + nom, sur la couleur sombre du parti.
struct PartyBadge: View {
    let candidate: Candidate
    var font: Font = .caption.weight(.bold)

    var body: some View {
        HStack(spacing: 6) {
            PartyMark(candidate: candidate, size: 16)
            Text(candidate.party ?? "Sans étiquette").font(font).lineLimit(1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(candidate.deep, in: .capsule)
        .overlay(Capsule().strokeBorder(.white.opacity(0.18)))
    }
}

// MARK: - Formats

extension Double {
    /// 33.9 → « 33,9 % »
    var percent: String { (self / 100).formatted(.percent.precision(.fractionLength(0...1))) }
}

extension Int {
    var ordinal: String { self == 1 ? "1er" : "\(self)e" }
}

extension Date {
    var short: String { formatted(.dateTime.day().month(.abbreviated).year()) }
}

// MARK: - Apparence

enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: "Automatique"
        case .light: "Clair"
        case .dark: "Sombre"
        }
    }
    var symbol: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }
    var scheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
