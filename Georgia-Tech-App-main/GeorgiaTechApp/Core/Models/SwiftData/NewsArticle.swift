//
//  NewsArticle.swift
//  GeorgiaTechApp
//

import Foundation
import SwiftData

/// A Georgia Tech news item from the combined campus feed — either a
/// full article ("news") or a brief outside-coverage mention
/// ("external_news"). Images are EXTERNAL urls the app loads lazily.
@Model final class NewsArticle {
    @Attribute(.unique) var newsID: String
    var title: String
    var subtitle: String
    var summary: String
    var body: String
    var categories: [String]
    var publishedDate: Date
    var sourceType: String
    var articleURL: String
    var publication: String
    var imageURL: String?
    var imageAlt: String?

    var isExternal: Bool { sourceType == "external_news" }

    init(
        newsID: String, title: String, subtitle: String, summary: String,
        body: String, categories: [String], publishedDate: Date,
        sourceType: String, articleURL: String, publication: String,
        imageURL: String?, imageAlt: String?
    ) {
        self.newsID = newsID
        self.title = title
        self.subtitle = subtitle
        self.summary = summary
        self.body = body
        self.categories = categories
        self.publishedDate = publishedDate
        self.sourceType = sourceType
        self.articleURL = articleURL
        self.publication = publication
        self.imageURL = imageURL
        self.imageAlt = imageAlt
    }
}
