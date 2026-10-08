import SwiftUI

@main
struct ElyseeApp: App {
    @State private var store = Store()
    @AppStorage("appearance") private var appearance = Appearance.system

    var body: some Scene {
        WindowGroup {
            Root().environment(store).preferredColorScheme(appearance.scheme)
        }
    }
}

struct Root: View {
    @Environment(Store.self) private var store
    @Environment(\.scenePhase) private var phase

    var body: some View {
        TabView {
            Tab("Candidats", systemImage: "person.3.fill") {
                NavigationStack { HomeView().withCandidateDestination() }
            }
            Tab("Le fil", systemImage: "newspaper.fill") {
                NavigationStack { FeedView().withCandidateDestination() }
            }
            Tab(role: .search) {
                NavigationStack { SearchView().withCandidateDestination() }
            }
        }
        .tint(.primary)
        .tabBarMinimizeBehavior(.onScrollDown)
        .task(id: phase) { if phase == .active { await store.refresh() } }
    }
}

extension View {
    func withCandidateDestination() -> some View {
        navigationDestination(for: Candidate.self) { CandidateView(candidate: $0) }
    }
}
