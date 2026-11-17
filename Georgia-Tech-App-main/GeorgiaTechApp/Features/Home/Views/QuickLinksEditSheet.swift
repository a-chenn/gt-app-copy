//
//  QuickLinksEditSheet.swift
//  GeorgiaTechApp
//

import SwiftUI

/// Manage the pinned campus links: swipe left to remove, press and
/// hold to drag-reorder (no edit mode needed), add from the catalog,
/// or create your own link. No cap — the home grid just grows.
struct QuickLinksEditSheet: View {
    @Binding var pinnedRaw: String
    @Environment(\.dismiss) private var dismiss

    @State private var isAddingCustom = false
    @State private var customTitle = ""
    @State private var customURL = ""
    @State private var customLinkError = false

    private var pinned: [CampusQuickLink] {
        QuickLinkStore.decode(pinnedRaw)
    }

    private var available: [CampusQuickLink] {
        let pinnedIDs = Set(pinned.map(\.id))
        return CampusQuickLink.catalog.filter { !pinnedIDs.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(pinned) { link in
                        row(link)
                            // An explicit swipe action rather than
                            // .onDelete: the implicit one was drawing its
                            // red short of the row's full height on the
                            // taller custom-link rows.
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    remove(link)
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                                // The screen's warm tint was painting the
                                // destructive role gold-navy; this is the
                                // palette's red.
                                .tint(Color.gtAzalea)
                            }
                    }
                    .onMove { source, destination in
                        var links = pinned
                        links.move(fromOffsets: source, toOffset: destination)
                        pinnedRaw = QuickLinkStore.encode(links)
                    }
                } header: {
                    Text("Your Links")
                        .font(.gtHeading6)
                        .foregroundStyle(Color.gtSecondaryText)
                } footer: {
                    Text("Swipe left to remove. Press and hold to reorder.")
                        .font(.gtBody3)
                }

                Section(header: Text("Add").font(.gtHeading6).foregroundStyle(Color.gtSecondaryText)) {
                    Button {
                        isAddingCustom = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "plus.app")
                                .font(.gtBody2)
                                .foregroundStyle(Color.gtPrimaryText)
                                .frame(width: 24)
                            Text("Create your own link")
                                .font(.gtBody2)
                                .foregroundStyle(Color.gtPrimaryText)
                        }
                    }
                    .accessibilityHint("Add a website of your choice to the home screen")

                    ForEach(available) { link in
                        Button {
                            append(link)
                        } label: {
                            HStack {
                                row(link)
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(Color.gtTechLawn)
                            }
                        }
                        .accessibilityLabel("Add \(link.title)")
                    }
                }
            }
            .navigationTitle("Campus Links")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("New Link", isPresented: $isAddingCustom) {
                TextField("Name", text: $customTitle)
                TextField("gatech.edu/…", text: $customURL)
                    .textInputAutocapitalization(.never)
                Button("Add") {
                    if let link = CampusQuickLink.custom(title: customTitle, urlText: customURL) {
                        append(link)
                        customTitle = ""
                        customURL = ""
                    } else {
                        customLinkError = true
                    }
                }
                Button("Cancel", role: .cancel) {
                    customTitle = ""
                    customURL = ""
                }
            } message: {
                Text("Links open in your browser after a confirmation.")
            }
            .alert("That link didn't look right", isPresented: $customLinkError) {
                Button("OK") { isAddingCustom = true }
            } message: {
                Text("Enter a name and a web address like example.gatech.edu.")
            }
        }
    }

    private func append(_ link: CampusQuickLink) {
        var links = pinned
        links.append(link)
        pinnedRaw = QuickLinkStore.encode(links)
    }

    private func remove(_ link: CampusQuickLink) {
        pinnedRaw = QuickLinkStore.encode(pinned.filter { $0.id != link.id })
    }

    private func row(_ link: CampusQuickLink) -> some View {
        HStack(spacing: 10) {
            Image(systemName: link.icon)
                .font(.gtBody2)
                .foregroundStyle(Color.gtPrimaryText)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(link.title)
                    .font(.gtBody2)
                    .foregroundStyle(Color.gtPrimaryText)
                if link.isCustom {
                    Text(link.urlString)
                        .font(.gtBody4)
                        .foregroundStyle(Color.gtSecondaryText)
                        .lineLimit(1)
                }
            }
        }
    }
}
