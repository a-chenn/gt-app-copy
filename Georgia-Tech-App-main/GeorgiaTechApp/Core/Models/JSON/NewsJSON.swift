//
//  NewsJSON.swift
//  GeorgiaTechApp
//

import Foundation

nonisolated struct NewsResponseJSON: Decodable, Sendable {
    let news: [NewsJSON]
    let totalCount: Int
    let lastUpdated: String

    enum CodingKeys: String, CodingKey {
        case news
        case totalCount = "total_count"
        case lastUpdated = "last_updated"
    }
}

nonisolated struct NewsJSON: Decodable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let summary: String
    let body: String
    let categories: [NewsCategoryJSON]
    /// ISO8601 UTC dateline.
    let published: String
    /// "news" or "external_news" (brief outside-coverage mentions).
    let sourceType: String
    let articleURL: String
    let publication: String
    /// Pre-sized (740px) https image URL when the article has one.
    let imageURL: String?
    let imageAlt: String?

    enum CodingKeys: String, CodingKey {
        case id, title, subtitle, summary, body, categories, published, publication
        case sourceType = "source_type"
        case articleURL = "article_url"
        case imageURL = "image_url"
        case imageAlt = "image_alt"
    }
}

nonisolated struct NewsCategoryJSON: Decodable, Sendable {
    let id: String
    let name: String
}
