//
//  GTDataService+News.swift
//  GeorgiaTechApp
//

import Foundation
import OSLog
import SwiftData

extension GTDataService {
    @discardableResult
    @MainActor func loadNews(context: ModelContext, forceRefresh: Bool = false) async -> Bool {
        await newsFetcher.load(context: context, forceRefresh: forceRefresh) {
            // The API accumulates news server-side from the combined feed
            // and serves a stable newest-first list.
            let response: NewsResponseJSON = try await self.fetch("news/?limit=200")

            let existing = try context.fetch(FetchDescriptor<NewsArticle>())

            // An empty feed with an EMPTY local cache is a legitimate
            // "no news yet" state (e.g. the API just deployed) — succeed
            // so the metadata stamp commits and the app stops retrying
            // every launch. With a POPULATED cache, empty means a
            // broken/transitional fetch: throw rather than wipe.
            guard !response.news.isEmpty else {
                if existing.isEmpty { return }
                throw URLError(.zeroByteResource)
            }
            let byID = Dictionary(
                existing.map { ($0.newsID, $0) },
                uniquingKeysWith: { first, _ in first })
            var fetchedIDs = Set<String>()

            for json in response.news {
                fetchedIDs.insert(json.id)
                if let current = byID[json.id] {
                    current.update(from: json)
                } else {
                    context.insert(NewsArticle(json: json))
                }
            }
            for article in existing where !fetchedIDs.contains(article.newsID) {
                context.delete(article)
            }
            try context.save()
        }
    }
}

extension NewsArticle {
    fileprivate convenience init(json: NewsJSON) {
        self.init(
            newsID: json.id,
            title: json.title,
            subtitle: json.subtitle,
            summary: json.summary,
            body: json.body,
            categories: json.categories.map(\.name),
            publishedDate: Self.date(from: json.published),
            sourceType: json.sourceType,
            articleURL: json.articleURL,
            publication: json.publication,
            imageURL: json.imageURL,
            imageAlt: json.imageAlt
        )
    }

    fileprivate func update(from json: NewsJSON) {
        title = json.title
        subtitle = json.subtitle
        summary = json.summary
        body = json.body
        categories = json.categories.map(\.name)
        publishedDate = Self.date(from: json.published)
        sourceType = json.sourceType
        articleURL = json.articleURL
        publication = json.publication
        imageURL = json.imageURL
        imageAlt = json.imageAlt
    }

    /// The API guarantees ISO8601 UTC datelines.
    private static func date(from string: String) -> Date {
        let iso = ISO8601DateFormatter()
        if let date = iso.date(from: string) {
            return date
        }
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return iso.date(from: string) ?? .distantPast
    }
}
