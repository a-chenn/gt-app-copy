//
//  NewsHomeViewModel.swift
//  GeorgiaTechApp
//

import Foundation
import Observation

// MARK: - Categories
// "All News" is intentionally NOT a category. It's the default state when
// `selectedCategory == nil`.

enum SampleNewsCategory: String, CaseIterable, Identifiable {
    case officialGT = "Official GT"
    case businessEconomic = "Business & Economic"
    case campus = "Campus & Student Life"
    case research = "Research & Innovation"
    case sports = "Sports"

    var id: String { rawValue }

    /// Heading shown when no category filter is active.
    static let defaultTitle = "All News"
}

// MARK: - Article blocks (each one is data-driven, so add/remove freely)

struct SampleRelatedLink: Identifiable, Hashable {
    let title: String
    let url: URL
    var id: String { url.absoluteString }
}

struct NewsContact: Identifiable, Hashable {
    var name: String?
    var email: String
    var id: String { email }
    var mailURL: URL? { URL(string: "mailto:\(email)") }
}

/// The icon row under the article subtitle (X, Facebook, LinkedIn, email).
/// To add a target: add a case, its icon, and its share URL below.
enum NewsShareTarget: String, CaseIterable, Hashable, Identifiable {
    case x, facebook, linkedIn, email

    static let defaults: [NewsShareTarget] = [.x, .facebook, .linkedIn, .email]

    var id: String { rawValue }

    var title: String {
        switch self {
        case .x: "Share on X"
        case .facebook: "Share on Facebook"
        case .linkedIn: "Share on LinkedIn"
        case .email: "Share by email"
        }
    }

    var icon: NewsIcon {
        switch self {
        case .x: .x
        case .facebook: .facebook
        case .linkedIn: .linkedIn
        case .email: .email
        }
    }

    func url(title: String, summary: String, link: URL) -> URL? {
        let t = Self.encode(title)
        let u = Self.encode(link.absoluteString)
        switch self {
        case .x:
            return URL(string: "https://twitter.com/intent/tweet?text=\(t)&url=\(u)")
        case .facebook:
            return URL(string: "https://www.facebook.com/sharer/sharer.php?u=\(u)")
        case .linkedIn:
            return URL(string: "https://www.linkedin.com/sharing/share-offsite/?url=\(u)")
        case .email:
            let body = Self.encode(summary + "\n\n" + link.absoluteString)
            return URL(string: "mailto:?subject=\(t)&body=\(body)")
        }
    }

    private static func encode(_ string: String) -> String {
        string.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? string
    }
}

// MARK: - Article

struct SampleNewsArticle: Identifiable, Hashable {
    let id: UUID
    let title: String
    let subtitle: String
    let summary: String
    let body: String
    let date: String
    let imageName: String
    let imageAlt: String
    let category: SampleNewsCategory
    let isFeatured: Bool
    let contacts: [NewsContact]
    let relatedLinks: [SampleRelatedLink]
    let shareURL: URL
    let shareTargets: [NewsShareTarget]

    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String,
        summary: String,
        body: String,
        date: String = "November 5, 2026",
        imageName: String,
        imageAlt: String,
        category: SampleNewsCategory,
        isFeatured: Bool = false,
        contacts: [NewsContact] = [NewsContact(name: "Georgia Tech", email: "news@gatech.edu")],
        relatedLinks: [SampleRelatedLink] = [],
        shareURL: URL = URL(string: "https://news.gatech.edu/")!,
        shareTargets: [NewsShareTarget] = NewsShareTarget.defaults
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.summary = summary
        self.body = body
        self.date = date
        self.imageName = imageName
        self.imageAlt = imageAlt
        self.category = category
        self.isFeatured = isFeatured
        self.contacts = contacts
        self.relatedLinks = relatedLinks
        self.shareURL = shareURL
        self.shareTargets = shareTargets
    }
}

// MARK: - Pluggable "You might also be interested in..."
// Swap `CategoryRelatedArticlesProvider` for a recommendation engine or an
// API-backed provider later without touching any view code.

protocol RelatedArticlesProviding: Sendable {
    func relatedArticles(
        for article: SampleNewsArticle,
        in articles: [SampleNewsArticle],
        limit: Int
    ) async -> [SampleNewsArticle]
}

struct CategoryRelatedArticlesProvider: RelatedArticlesProviding {
    func relatedArticles(
        for article: SampleNewsArticle,
        in articles: [SampleNewsArticle],
        limit: Int
    ) async -> [SampleNewsArticle] {
        let others = articles.filter { $0.id != article.id }
        let sameCategory = others.filter { $0.category == article.category }
        let rest = others.filter { $0.category != article.category }
        return Array((sameCategory + rest).prefix(limit))
    }
}

// MARK: - Pluggable search
// `KeywordNewsSearch` is used today. To add semantic search, write a type that
// conforms to `NewsSearching` (e.g. on-device NLEmbedding or a server call that
// returns articles ranked by similarity) and pass it into `NewsHomeViewModel`.

protocol NewsSearching: Sendable {
    func search(_ query: String, in articles: [SampleNewsArticle]) async -> [SampleNewsArticle]
}

struct KeywordNewsSearch: NewsSearching {
    func search(_ query: String, in articles: [SampleNewsArticle]) async -> [SampleNewsArticle] {
        let tokens = query.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !tokens.isEmpty else { return articles }
        return articles.filter { article in
            let haystack = [article.title, article.subtitle, article.summary, article.body, article.category.rawValue]
                .joined(separator: " ")
            return tokens.allSatisfy { haystack.localizedCaseInsensitiveContains($0) }
        }
    }
}

// MARK: - View model

@MainActor
@Observable
final class NewsHomeViewModel {
    var selectedCategory: SampleNewsCategory?
    var searchText = ""
    var showingCategoryMenu = false
    private(set) var searchResults: [SampleNewsArticle] = []

    let searchEngine: any NewsSearching
    let relatedProvider: any RelatedArticlesProviding

    init(
        searchEngine: any NewsSearching = KeywordNewsSearch(),
        relatedProvider: any RelatedArticlesProviding = CategoryRelatedArticlesProvider()
    ) {
        self.searchEngine = searchEngine
        self.relatedProvider = relatedProvider
    }

    let articles: [SampleNewsArticle] = [
        SampleNewsArticle(
            title: "Georgia Tech and Emory Invest More Than $1B in AI to Drive State’s Jobs, Economic Growth",
            subtitle: "The funding strengthens Georgia’s ability to attract companies, develop talent, and accelerate Atlanta’s growth as a leading tech hub.",
            summary: "Together, Georgia Tech and Emory University are investing more than $1 billion in artificial intelligence.",
            body: """
            ATLANTA — Together, Georgia Tech and Emory University are investing more than $1 billion in artificial intelligence (AI), building one of the nation’s most robust AI ecosystems in the city of Atlanta.

            The combined commitment — approximately $600 million from Emory and more than $575 million from Georgia Tech — strengthens Atlanta’s competitiveness for new business growth, skilled workers, investment, and federal research funding.

            The institutions contribute unique capabilities that span the full AI innovation pipeline. Georgia Tech’s investments focus on advanced computing, AI discovery, and workforce development — with the goal of developing leaders who will shape AI use for human good. Emory’s investments cultivate AI talent, healthcare innovation, and technology applications in medicine, business, law, the humanities, and ethics. Additionally, Georgia Tech and Emory will collaborate where their strengths intersect, creating new opportunities for research partnerships, talent development, industry engagement, and AI-enabled innovation.

            “Georgia is poised to be a national leader in advanced, responsible AI development that can be counted on to produce the talent, infrastructure, and innovation companies need,” said Georgia Tech President Ángel Cabrera. “The combined strengths of Georgia Tech and Emory will help make Atlanta a leading AI hub that drives breakthrough discoveries, launches new ventures, powers industries, and fuels economic growth.”

            “Atlanta is unique because of what we can accomplish together,” said Emory University President Christopher L. Augostini. “The collaboration between our universities and leaders in government and business allows us to identify and respond to the opportunities AI offers our state to accelerate discovery and improve lives. The combination of Emory’s expertise in the liberal arts and health sciences with Georgia Tech’s leadership in technology and engineering makes our region a national leader in AI.”
            """,
            date: "October 8, 2026",
            imageName: "NewsCampus",
            imageAlt: "Georgia Tech campus and Atlanta skyline",
            category: .businessEconomic,
            isFeatured: true,
            contacts: [
                NewsContact(name: "Georgia Tech", email: "media@gatech.edu"),
                NewsContact(name: "Emory University", email: "news@emory.edu")
            ],
            relatedLinks: [
                SampleRelatedLink(
                    title: "Georgia Tech AI research",
                    url: URL(string: "https://www.gatech.edu/")!
                )
            ]
        ),
        SampleNewsArticle(
            title: "Georgia Tech Announces New Online Master’s Degree in Artificial Intelligence",
            subtitle: "A new pathway expands access to advanced computing education.",
            summary: "The new degree aims to prepare professionals to apply AI responsibly in their fields.",
            body: "Georgia Tech is expanding access to advanced computing education with a new online master’s degree in artificial intelligence. Students will explore machine learning, data-driven systems, and responsible AI through flexible coursework designed for working professionals.",
            date: "October 6, 2026",
            imageName: "NewsGraduates",
            imageAlt: "Georgia Tech graduates celebrating commencement",
            category: .research,
            isFeatured: true
        ),
        SampleNewsArticle(
            title: "What Makes a Computer ‘Think’? Inside Supercomputing at Georgia Tech",
            subtitle: "Researchers explain how high-performance computing tackles complex problems.",
            summary: "Here’s a look inside supercomputing and the people behind it.",
            body: "Georgia Tech researchers use high-performance computing to model complex systems, analyze large datasets, and explore new approaches in engineering, medicine, and science. The work brings together students, faculty, and research teams across campus.",
            imageName: "NewsComputer",
            imageAlt: "Researcher working with computing equipment",
            category: .research
        ),
        SampleNewsArticle(
            title: "Ramblin’ Wreck Celebrates 65 Years of Tradition",
            subtitle: "The beloved campus icon continues to connect generations of Yellow Jackets.",
            summary: "It’s been 65 years since the mechanical marvel became a fixture at Tech.",
            body: "Students and alumni gathered to celebrate the history of the Ramblin’ Wreck and the traditions that make Georgia Tech unique. The classic car remains one of the most recognizable symbols of campus spirit.",
            imageName: "NewsWreck",
            imageAlt: "Classic vintage automobile",
            category: .officialGT
        ),
        SampleNewsArticle(
            title: "The Month in Photos: September on Campus",
            subtitle: "A look back at campus events, milestones, and student life.",
            summary: "Groundbreakings, ribbon-cuttings, and memorable moments from September.",
            body: "From student organizations to campus research and community celebrations, September brought a range of activities and milestones across Georgia Tech.",
            imageName: "NewsConstruction",
            imageAlt: "Campus construction and new building project",
            category: .campus
        ),
        SampleNewsArticle(
            title: "Can Brain Activity Reveal How We Learn?",
            subtitle: "A researcher discusses new insights into memory and cognition.",
            summary: "D.J. Wu discusses how brain activity may reveal the learning process.",
            body: "The research explores how patterns of brain activity relate to attention, memory, and learning, with potential implications for educational and cognitive science.",
            imageName: "NewsResearcher",
            imageAlt: "Georgia Tech researcher",
            category: .research
        ),
        SampleNewsArticle(
            title: "Yellow Jackets Prepare for a Big Weekend of Competition",
            subtitle: "Student-athletes gear up for upcoming matchups.",
            summary: "Teams are preparing for a busy weekend across several sports.",
            body: "Georgia Tech athletics enters a full weekend of competition. Fans can follow schedules, results, and updates through official athletics channels.",
            imageName: "NewsCampus",
            imageAlt: "Georgia Tech campus",
            category: .sports
        ),
        SampleNewsArticle(
            title: "Students Turn Ideas Into Impact at Campus Innovation Showcase",
            subtitle: "Projects highlight creativity, collaboration, and problem-solving.",
            summary: "Student teams shared prototypes and ideas with the campus community.",
            body: "The showcase featured student projects spanning sustainability, computing, design, and community-focused technology.",
            imageName: "NewsGraduates",
            imageAlt: "Students at a university event",
            category: .campus
        ),
        SampleNewsArticle(
            title: "Georgia Tech Researchers Explore More Sustainable Materials",
            subtitle: "New work investigates materials designed for a lower environmental impact.",
            summary: "The team is exploring how materials science can support sustainable manufacturing.",
            body: "Researchers are studying material properties and manufacturing methods with the goal of improving efficiency and reducing waste.",
            imageName: "NewsConstruction",
            imageAlt: "Campus research and construction",
            category: .businessEconomic
        )
    ]

    // MARK: Derived state

    var trimmedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isSearching: Bool { !trimmedQuery.isEmpty }

    /// True when the home screen should show the plain "Recommended + All News" layout.
    var isShowingDefaultHome: Bool { selectedCategory == nil && !isSearching }

    /// "All News" heading only appears in the default state (per Figma, filtered
    /// and search views show the grid with no heading).
    var sectionTitle: String? {
        isShowingDefaultHome ? SampleNewsCategory.defaultTitle : nil
    }

    var filteredArticles: [SampleNewsArticle] {
        let base = isSearching ? searchResults : articles
        guard let selectedCategory else { return base }
        return base.filter { $0.category == selectedCategory }
    }

    var recommendedArticles: [SampleNewsArticle] {
        articles.filter(\.isFeatured)
    }

    // MARK: Actions

    /// Call from `.task(id: searchText)`. Debounces, then asks the search engine.
    func refreshSearch() async {
        let query = trimmedQuery
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        try? await Task.sleep(for: .milliseconds(250))
        guard !Task.isCancelled else { return }
        let results = await searchEngine.search(query, in: articles)
        guard !Task.isCancelled else { return }
        searchResults = results
    }

    /// `nil` clears the filter and returns to the default "All News" state.
    func selectCategory(_ category: SampleNewsCategory?) {
        selectedCategory = category
        showingCategoryMenu = false
    }

    func toggleCategory(_ category: SampleNewsCategory) {
        selectCategory(selectedCategory == category ? nil : category)
    }
}
