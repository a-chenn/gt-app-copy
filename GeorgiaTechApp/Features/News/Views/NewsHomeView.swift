//
//  NewsHomeView.swift
//  GeorgiaTechApp
//
//  Temporary sample-data News experience. No SwiftData writes.
//

import SwiftUI

// MARK: - Icons (single place to match Figma)
// Icons use an SF Symbol (or a drawn badge for brand logos) by default.
// To use a Figma export instead: add a template-rendered image set named
// "NewsIcon-<case>" (e.g. "NewsIcon-x") to the asset catalog, then add that
// case to `NewsIcon.customAssetIcons` below. SwiftUI can't check whether an
// asset exists at runtime, so this list is the single switch.

enum NewsIcon: String {
    case search, close, filter, chevron, back
    case email, contact, link
    case x, facebook, linkedIn

    /// Icons that have a Figma export in the asset catalog.
    static let customAssetIcons: Set<NewsIcon> = []

    var assetName: String { "NewsIcon-\(rawValue)" }
    var hasCustomAsset: Bool { Self.customAssetIcons.contains(self) }

    var systemName: String? {
        switch self {
        case .search: "magnifyingglass"
        case .close: "xmark"
        case .filter: "line.3.horizontal.decrease"
        case .chevron: "chevron.right"
        case .back: "chevron.left"
        case .email: "envelope"
        case .contact: "person"
        case .link: "link"
        case .x, .facebook, .linkedIn: nil
        }
    }

    /// Letters used for the fallback badge on brand icons.
    var brandGlyph: String? {
        switch self {
        case .x: "X"
        case .facebook: "f"
        case .linkedIn: "in"
        default: nil
        }
    }
}

struct NewsIconView: View {
    let icon: NewsIcon
    var size: CGFloat = 20
    var weight: Font.Weight = .regular

    var body: some View {
        if icon.hasCustomAsset {
            Image(icon.assetName)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else if let systemName = icon.systemName {
            Image(systemName: systemName)
                .font(.system(size: size, weight: weight))
                .frame(width: size, height: size)
        } else if let glyph = icon.brandGlyph {
            RoundedRectangle(cornerRadius: size * 0.16, style: .continuous)
                .fill(Color.gtPrimaryText)
                .frame(width: size, height: size)
                .overlay {
                    Text(glyph)
                        .font(.system(size: size * 0.58, weight: .bold))
                        .foregroundStyle(Color.gtWhite)
                }
        }
    }
}

// MARK: - Shared layout (tweak spacing in one place)

private enum NewsLayout {
    static let gridSpacing: CGFloat = 12
    static let rowSpacing: CGFloat = 16
    static let featuredAspect: CGFloat = 1.8
    static let compactAspect: CGFloat = 1.9
    static let columns = [
        GridItem(.flexible(), spacing: gridSpacing, alignment: .top),
        GridItem(.flexible(), spacing: gridSpacing, alignment: .top)
    ]
}

// MARK: - Home

struct NewsHomeView: View {
    var isEmbedded: Bool = false
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = NewsHomeViewModel()
    @State private var showingSearch = false

    var body: some View {
        VStack(spacing: 0) {
            header
            categoryBar
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if viewModel.isShowingDefaultHome {
                        recommendedSection
                        sectionDivider
                    }
                    allNewsSection
                }
                .padding(.bottom, 24)
            }
            .background(Color.gtBackground)
        }
        .background(Color.gtBackground.ignoresSafeArea())
        .toolbar(
            isEmbedded ? .visible : .hidden,
            for: .navigationBar
        )
        .task(id: viewModel.searchText) {
            await viewModel.refreshSearch()
        }
    }

    private func detail(for article: SampleNewsArticle) -> some View {
        SampleNewsDetailView(
            article: article,
            allArticles: viewModel.articles,
            relatedProvider: viewModel.relatedProvider
        )
    }
}

// MARK: - Header and categories

private extension NewsHomeView {
    var header: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                if !isEmbedded {
                    Button {
                        dismiss()
                    } label: {
                        NewsIconView(icon: .back, size: 18, weight: .semibold)
                            .foregroundStyle(Color.gtPrimaryText)
                            .frame(width: 28, height: 36)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Back")
                }

                Text("News")
                    .font(.gtHeading2)
                    .foregroundStyle(Color.gtPrimaryText)

                Spacer()

                // Keep your existing search button here.

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showingSearch.toggle()

                        if !showingSearch {
                            viewModel.searchText = ""
                        }
                    }
                } label: {
                    NewsIconView(
                        icon: showingSearch ? .close : .search,
                        size: 21,
                        weight: .semibold
                    )
                    .foregroundStyle(Color.gtPrimaryText)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
                }
                .accessibilityLabel(
                    showingSearch ? "Close search" : "Search news"
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 14)

            if showingSearch {
                HStack(spacing: 10) {
                    NewsIconView(icon: .search, size: 16)
                        .foregroundStyle(Color.gtSecondaryText)
                    TextField("Search news", text: $viewModel.searchText)
                        .font(.gtBody2)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                }
                .padding(.horizontal, 14)
                .frame(height: 42)
                .background(Color.gtWhite, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .background(Color.gtBackground)
    }

    
    var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Menu {
                    ForEach(SampleNewsCategory.allCases) { category in
                        Button {
                            viewModel.toggleCategory(category)
                        } label: {
                            if viewModel.selectedCategory == category {
                                Label(category.rawValue, systemImage: "checkmark")
                            } else {
                                Text(category.rawValue)
                            }
                        }
                    }
                } label: {
                    NewsIconView(icon: .filter, size: 17, weight: .medium)
                        .foregroundStyle(Color.gtPrimaryText)
                        .frame(width: 40, height: 40)
                        .background(Color.gtWhite, in: Circle())
                        .overlay(
                            Circle().stroke(Color.gtOverlay1, lineWidth: 0.5)
                        )
                        .contentShape(Circle())
                }
                .accessibilityLabel("Filter news by category")

                ForEach(SampleNewsCategory.allCases) { category in
                    categoryChip(category)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
        }
        .background(Color.gtBackground)
        .overlay(alignment: .bottom) {
            sectionDivider
        }
    }

    func categoryChip(_ category: SampleNewsCategory) -> some View {
        let isSelected = viewModel.selectedCategory == category
        return Button {
            viewModel.toggleCategory(category)
        } label: {
            Text(category.rawValue)
                .font(.gtBody3)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .foregroundStyle(isSelected ? Color.gtWhite : Color.gtPrimaryText)
                .padding(.horizontal, 14)
                .frame(height: 40)
                .background(isSelected ? Color.gtNavy : Color.gtWhite, in: Capsule())
                .overlay(Capsule().stroke(isSelected ? Color.clear : Color.gtOverlay1, lineWidth: 0.5))
                .shadow(color: .black.opacity(isSelected ? 0.08 : 0.04), radius: 3, y: 1)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    var sectionDivider: some View {
        Rectangle()
            .fill(Color.gtOverlay1)
            .frame(height: 0.5)
    }
}

// MARK: - Home sections

private extension NewsHomeView {
    var recommendedSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Recommended News")
                    .font(.gtHeading3)
                    .foregroundStyle(Color.gtPrimaryText)
                Spacer()
                NavigationLink {
                    NewsCollectionView(
                        title: "Recommended News",
                        articles: viewModel.recommendedArticles,
                        allArticles: viewModel.articles,
                        relatedProvider: viewModel.relatedProvider
                    )
                } label: {
                    NewsIconView(icon: .chevron, size: 17, weight: .semibold)
                        .foregroundStyle(Color.gtPrimaryText)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("See all recommended news")
            }

            VStack(spacing: 24) {
                ForEach(viewModel.recommendedArticles) { article in
                    NavigationLink {
                        detail(for: article)
                    } label: {
                        FeaturedNewsCard(article: article)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 24)
    }

    var allNewsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let title = viewModel.sectionTitle {
                Text(title)
                    .font(.gtHeading3)
                    .foregroundStyle(Color.gtPrimaryText)
            }

            if viewModel.filteredArticles.isEmpty {
                ContentUnavailableView(
                    "No News Found",
                    systemImage: "newspaper",
                    description: Text("Try another category or search term.")
                )
                .padding(.vertical, 32)
            } else {
                LazyVGrid(columns: NewsLayout.columns, alignment: .center, spacing: NewsLayout.rowSpacing) {
                    ForEach(viewModel.filteredArticles) { article in
                        NavigationLink {
                            detail(for: article)
                        } label: {
                            CompactNewsCard(article: article)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, viewModel.sectionTitle == nil ? 16 : 24)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Cards (match Figma: featured = title / date / summary, compact = title / summary)

private struct FeaturedNewsCard: View {
    let article: SampleNewsArticle

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SampleArticleImage(article: article, aspectRatio: NewsLayout.featuredAspect)
            VStack(alignment: .leading, spacing: 3) {
                Text(article.title)
                    .font(.gtHeading5)
                    .foregroundStyle(Color.gtPrimaryText)
                    .lineLimit(2)
                Text(article.date)
                    .font(.gtBody4)
                    .foregroundStyle(Color.gtSecondaryText)
                    .lineLimit(1)
                Text(article.summary)
                    .font(.gtBody4)
                    .foregroundStyle(Color.gtSecondaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.top, 3)
            }
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .contentShape(Rectangle())
    }
}

private struct CompactNewsCard: View {
    let article: SampleNewsArticle

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SampleArticleImage(article: article, aspectRatio: NewsLayout.compactAspect)
            VStack(alignment: .leading, spacing: 2) {
                Text(article.title)
                    .font(.gtHeading6)
                    .foregroundStyle(Color.gtPrimaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(article.summary)
                    .font(.gtBody4)
                    .foregroundStyle(Color.gtSecondaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .contentShape(Rectangle())
    }
}

// MARK: - Image
// A sized placeholder + overlay stops `scaledToFill` from pushing the image
// wider than its grid column.

private struct SampleArticleImage: View {
    let article: SampleNewsArticle
    let aspectRatio: CGFloat
    var cornerRadius: CGFloat = 12

    var body: some View {
        Color.gtGray1
            .aspectRatio(aspectRatio, contentMode: .fit)
            .overlay {
                Image(article.imageName)
                    .resizable()
                    .scaledToFill()
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .accessibilityLabel(article.imageAlt)
    }
}

// MARK: - Collection screen

private struct NewsCollectionView: View {
    let title: String
    let articles: [SampleNewsArticle]
    let allArticles: [SampleNewsArticle]
    let relatedProvider: any RelatedArticlesProviding

    var body: some View {
        ScrollView {
            LazyVGrid(columns: NewsLayout.columns, alignment: .center, spacing: NewsLayout.rowSpacing) {
                ForEach(articles) { article in
                    NavigationLink {
                        SampleNewsDetailView(
                            article: article,
                            allArticles: allArticles,
                            relatedProvider: relatedProvider
                        )
                    } label: {
                        CompactNewsCard(article: article)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 24)
        }
        .gtScreenBackground()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Detail

private struct SampleNewsDetailView: View {
    let article: SampleNewsArticle
    let allArticles: [SampleNewsArticle]
    let relatedProvider: any RelatedArticlesProviding

    @State private var relatedArticles: [SampleNewsArticle] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SampleArticleImage(article: article, aspectRatio: NewsLayout.featuredAspect, cornerRadius: 0)

                VStack(alignment: .leading, spacing: 14) {
                    Text(article.title)
                        .font(.gtHeading3)
                        .foregroundStyle(Color.gtPrimaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(article.subtitle)
                        .font(.gtBody2)
                        .foregroundStyle(Color.gtSecondaryText)

                    NewsShareRow(article: article)

                    Text(article.date)
                        .font(.gtBody4)
                        .foregroundStyle(Color.gtSecondaryText)

                    Text(article.body)
                        .font(.gtBody3)
                        .foregroundStyle(Color.gtPrimaryText)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)

                    // Each block below is data-driven from the article model.
                    NewsContactsCard(contacts: article.contacts)
                    NewsRelatedLinksCard(links: article.relatedLinks)
                    RelatedArticlesSection(
                        articles: relatedArticles,
                        allArticles: allArticles,
                        relatedProvider: relatedProvider
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
        }
        .gtScreenBackground()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: article.id) {
            relatedArticles = await relatedProvider.relatedArticles(for: article, in: allArticles, limit: 4)
        }
    }
}

// MARK: - Detail blocks

/// Share icons under the subtitle. Driven by `article.shareTargets`.
private struct NewsShareRow: View {
    let article: SampleNewsArticle

    var body: some View {
        HStack(spacing: 14) {
            ForEach(article.shareTargets) { target in
                if let url = target.url(title: article.title, summary: article.summary, link: article.shareURL) {
                    Link(destination: url) {
                        NewsIconView(icon: target.icon, size: 24)
                            .foregroundStyle(Color.gtPrimaryText)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel(target.title)
                }
            }
        }
    }
}

/// Shared chrome for icon + heading + content cards.
private struct NewsInfoCard<Content: View>: View {
    let icon: NewsIcon
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            NewsIconView(icon: icon, size: 24)
                .foregroundStyle(Color.gtPrimaryText)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.gtHeading6)
                    .foregroundStyle(Color.gtNavy)
                content
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gtWhite, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.07), radius: 5, y: 2)
    }
}

private struct NewsContactsCard: View {
    let contacts: [NewsContact]

    /// "Georgia Tech: media@gatech.edu" with the address as an underlined mailto link.
    private func line(for contact: NewsContact) -> AttributedString {
        var text = AttributedString(contact.name.map { "\($0): " } ?? "")
        var address = AttributedString(contact.email)
        if let url = contact.mailURL { address.link = url }
        address.underlineStyle = .single
        text.append(address)
        return text
    }

    var body: some View {
        if !contacts.isEmpty {
            NewsInfoCard(icon: .contact, title: "CONTACT") {
                ForEach(contacts) { contact in
                    Text(line(for: contact))
                        .font(.gtBody4)
                        .foregroundStyle(Color.gtPrimaryText)
                        .tint(Color.gtPrimaryText)
                }
            }
            .padding(.top, 4)
        }
    }
}

private struct NewsRelatedLinksCard: View {
    let links: [SampleRelatedLink]

    var body: some View {
        NewsInfoCard(icon: .link, title: "RELATED LINKS") {
            if links.isEmpty {
                Text("None")
                    .font(.gtBody4)
                    .foregroundStyle(Color.gtPrimaryText)
            } else {
                ForEach(links) { link in
                    Link(link.title, destination: link.url)
                        .font(.gtBody4)
                        .foregroundStyle(Color.gtPrimaryText)
                        .underline()
                }
            }
        }
        .padding(.bottom, 2)
    }
}

private struct RelatedArticlesSection: View {
    let articles: [SampleNewsArticle]
    let allArticles: [SampleNewsArticle]
    let relatedProvider: any RelatedArticlesProviding

    var body: some View {
        if !articles.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                Text("You might also be interested in...")
                    .font(.gtHeading3)
                    .foregroundStyle(Color.gtPrimaryText)

                LazyVGrid(columns: NewsLayout.columns, alignment: .center, spacing: NewsLayout.rowSpacing) {
                    ForEach(articles) { related in
                        NavigationLink {
                            SampleNewsDetailView(
                                article: related,
                                allArticles: allArticles,
                                relatedProvider: relatedProvider
                            )
                        } label: {
                            CompactNewsCard(article: related)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.top, 2)
        }
    }
}

#Preview {
    NavigationStack {
        NewsHomeView()
    }
}
