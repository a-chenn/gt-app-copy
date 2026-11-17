//
//  NewsViews.swift
//  GeorgiaTechApp
//

import SwiftData
import SwiftUI

// MARK: - News list (the News half of the Events | News screen)

/// Newest-first campus news. Thumbnails are EXTERNAL urls loaded lazily
/// by AsyncImage inside the lazy stack — an article without an image gets
/// no reserved slot, so nothing looks broken when art is missing.
///
/// "In the news" press mentions are excluded. Verified against the live
/// feed: GT publishes a headline for them and nothing else — no body, no
/// summary, no link to the outlet — so every one of them opened a screen
/// with nothing on it. A row that can only disappoint is worse than no
/// row. They come back the moment the feed carries text or a URL.
struct NewsListContent: View {
    @Query(
        filter: #Predicate<NewsArticle> { $0.sourceType != "external_news" },
        sort: \NewsArticle.publishedDate, order: .reverse)
    private var articles: [NewsArticle]

    var body: some View {
        if articles.isEmpty {
            ContentUnavailableView(
                "No News Yet",
                systemImage: "newspaper",
                description: Text("Campus news will show up here.")
            )
            .padding(.top, 60)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                GTSectionHeader("Latest")
                    .padding(.horizontal, 16)

                LazyVStack(spacing: 0) {
                    ForEach(articles) { article in
                        NavigationLink(destination: NewsDetailView(article: article)) {
                            NewsRow(article: article)
                        }
                        .buttonStyle(.plain)

                        if article.newsID != articles.last?.newsID {
                            Divider()
                                .overlay(Color.gtNavy.opacity(0.08))
                                .padding(.leading, 90)
                        }
                    }
                }
                .gtCard(radius: 18, padding: 0)
                .padding(.horizontal, 16)
            }
        }
    }
}

// MARK: - Row

private struct NewsRow: View {
    @Environment(\.colorScheme) private var colorScheme

    let article: NewsArticle

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let urlString = article.imageURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        Color.gtSecondaryText.opacity(0.12)
                            .overlay {
                                Image(systemName: "newspaper")
                                    .font(.gtBody3)
                                    .foregroundStyle(Color.gtSecondaryText)
                            }
                    }
                }
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityLabel(article.imageAlt ?? "Article image")
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(kicker)
                    .font(.gtHeading6)
                    .tracking(1.4)
                    .textCase(.uppercase)
                    .foregroundStyle((colorScheme == .dark ? Color.gtGold : Color.gtDarkGold))
                    .lineLimit(1)

                Text(article.title)
                    .font(.gtHeading5)
                    .foregroundStyle(Color.gtPrimaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if !article.summary.isEmpty {
                    Text(article.summary)
                        .font(.gtBody3)
                        .foregroundStyle(Color.gtSecondaryText)
                        .lineLimit(2)
                }

                Text(article.publishedDate.formatted(.relative(presentation: .named)))
                    .font(.gtBody4)
                    .foregroundStyle(Color.gtSecondaryText)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.gtHeading6)
                .foregroundStyle(Color.gtSecondaryText.opacity(0.6))
                .padding(.top, 4)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    /// The category leads the row now, so the date line no longer has to
    /// carry it as a "· suffix".
    private var kicker: String {
        article.categories.first ?? "Georgia Tech"
    }

    private var dateText: String {
        article.publishedDate.formatted(date: .abbreviated, time: .omitted)
    }
}

// MARK: - Detail

struct NewsDetailView: View {
    let article: NewsArticle

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                GTDetailHero(
                    eyebrow: kicker,
                    title: article.title,
                    image: article.imageURL,
                    imageCaption: dateText,
                    accessibilityText: "\(kicker). \(article.title). \(dateText)"
                ) {
                    // Without art the date has nowhere else to go.
                    if article.imageURL == nil {
                        Text(dateText)
                            .font(.gtHeading6)
                            .foregroundStyle(Color.gtSecondaryText)
                    }
                }

                if !article.subtitle.isEmpty {
                    Text(article.subtitle)
                        .font(.gtHeading4)
                        .foregroundStyle(Color.gtSecondaryText)
                }

                // Body when the feed has one, summary as the fallback —
                // never both, they repeat each other.
                let story = article.body.isEmpty ? article.summary : article.body
                if !story.isEmpty {
                    GTBodyText(text: story)
                        .gtCard()
                }

                if !article.articleURL.isEmpty, URL(string: article.articleURL) != nil {
                    ExternalLinkButton(url: URL(string: article.articleURL)) {
                        Label(
                            article.publication.isEmpty
                                ? "Read the full article"
                                : "Read on \(article.publication)",
                            systemImage: "arrow.up.forward.app")
                            .font(.gtHeading4)
                            .textCase(.uppercase)
                            .tracking(1.1)
                            .foregroundStyle(Color.gtNavy)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(LinearGradient.gtGoldGradient, in: .capsule)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open the full article")
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .gtScreenBackground()
        .navigationTitle("News")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var kicker: String {
        article.categories.first ?? "Georgia Tech"
    }

    private var dateText: String {
        article.publishedDate.formatted(date: .abbreviated, time: .omitted)
    }
}
