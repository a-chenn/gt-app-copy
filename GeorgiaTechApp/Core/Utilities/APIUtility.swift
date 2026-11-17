//
//  APIUtility.swift
//  GeorgiaTechApp
//

import Foundation

enum APIUtility {
    static let baseURL: String? = {
        guard let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
              let urlString = dict["GTAPI"] as? String, !urlString.isEmpty
        else { return nil }
        return urlString
    }()
    
    static func url(for endpoint: String) throws -> URL {
        guard let base = baseURL else { throw URLError(.badURL) }
        guard let url = URL(string: base + endpoint) else { throw URLError(.badURL) }
        return url
    }
}
