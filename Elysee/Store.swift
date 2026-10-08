import Foundation
import Observation

/// Données affichées : copie embarquée → cache local → JSON distant (régénéré toutes les 6 h par GitHub Actions).
/// Le fichier distant remplace tout : un candidat retiré disparaît.
@Observable @MainActor
final class Store {
    static let remote = URL(string: "https://raw.githubusercontent.com/kameltovic/presidentielle-2027/main/data/candidats.json")!
    private static let cache = URL.applicationSupportDirectory.appending(path: "candidats.json")

    private(set) var data: Dataset
    private(set) var error: String?
    /// Candidats suivis (slugs), gardés sur l'appareil.
    private(set) var favorites: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "favorites") ?? [])

    init() {
        let local = (try? Data(contentsOf: Self.cache)).flatMap { try? JSONDecoder.dataset.decode(Dataset.self, from: $0) }
        let bundled = try! JSONDecoder.dataset.decode(Dataset.self, from: Data(contentsOf: Bundle.main.url(forResource: "candidats", withExtension: "json")!))
        data = [local, bundled].compactMap(\.self).max { $0.updatedAt < $1.updatedAt }!
    }

    func refresh() async {
        do {
            var req = URLRequest(url: Self.remote)
            req.cachePolicy = .reloadIgnoringLocalCacheData
            let (raw, resp) = try await URLSession.shared.data(for: req)
            // Pas encore publié (404) ou serveur en panne : on garde les données actuelles, sans alarmer.
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else { error = nil; return }
            let fresh = try JSONDecoder.dataset.decode(Dataset.self, from: raw)
            error = nil
            guard fresh.updatedAt > data.updatedAt else { return }
            data = fresh
            try? FileManager.default.createDirectory(at: Self.cache.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? raw.write(to: Self.cache)
        } catch {
            self.error = "Hors ligne — données du \(data.updatedAt.formatted(date: .abbreviated, time: .shortened))"
        }
    }

    func candidates(_ status: Status, matching query: String = "") -> [Candidate] {
        data.candidats
            .filter { $0.status == status }
            .filter { query.isEmpty || "\($0.name) \($0.party ?? "")".localizedStandardContains(query) }
            .sorted { $0.sortName.localizedStandardCompare($1.sortName) == .orderedAscending }
    }

    /// Classés par moyenne des sondages récents.
    var ranked: [Candidate] {
        data.candidats.filter { $0.rank != nil }.sorted { $0.rank! < $1.rank! }
    }

    func isFavorite(_ c: Candidate) -> Bool { favorites.contains(c.slug) }

    func toggleFavorite(_ c: Candidate) {
        if favorites.remove(c.slug) == nil { favorites.insert(c.slug) }
        UserDefaults.standard.set(Array(favorites), forKey: "favorites")
    }

    /// Favoris encore présents dans les données (un candidat retiré disparaît), dans l'ordre alphabétique.
    var favoriteCandidates: [Candidate] {
        data.candidats.filter { favorites.contains($0.slug) }.sorted { $0.sortName.localizedStandardCompare($1.sortName) == .orderedAscending }
    }

    func candidate(_ slug: String) -> Candidate? { data.candidats.first { $0.slug == slug } }
}
