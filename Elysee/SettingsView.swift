import SwiftUI

struct SettingsView: View {
    @AppStorage("appearance") private var appearance = Appearance.system
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Apparence") {
                    Picker("Apparence", selection: $appearance) {
                        ForEach(Appearance.allCases) { Label($0.title, systemImage: $0.symbol).tag($0) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                Section("Données") {
                    LabeledContent("Mise à jour", value: store.data.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    if let p = store.data.polls {
                        LabeledContent("Sondages", value: "\(p.polls) · \(p.hypotheses) hypothèses")
                        Link("Liste des sondages (Wikipédia)", destination: p.source)
                    }
                    Link("Liste des candidatures (Wikipédia)", destination: URL(string: "https://fr.wikipedia.org/wiki/Candidatures_%C3%A0_l%27%C3%A9lection_pr%C3%A9sidentielle_fran%C3%A7aise_de_2027")!)
                }
                Section {
                    Text("Classement : moyenne de toutes les hypothèses publiées dans les 30 jours précédant le dernier sondage. Un candidat n'est classé que s'il est testé dans au moins un quart des hypothèses.")
                    Text("Sources : Wikipédia (CC BY-SA), Wikidata, Bing Actualités, YouTube, Apple Podcasts, Bluesky. Mêmes informations et même présentation pour chaque candidat.")
                } header: { Text("Méthode") }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Réglages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("OK") { dismiss() } } }
        }
    }
}
