//
//  URLResponse+Validation.swift
//  GeorgiaTechApp
//

import Foundation

extension URLResponse {
    /// Validates that the response is an HTTPURLResponse and has a 2xx status code.
    func validate(orThrow error: Error? = nil) throws {
        guard let httpResponse = self as? HTTPURLResponse else {
            throw error ?? URLError(.badServerResponse)
        }
        guard (200...299).contains(httpResponse.statusCode) else {
#if DEBUG
            print("Request failed with HTTP status \(httpResponse.statusCode)")
#endif
            throw error ?? URLError(.badServerResponse)
        }
    }
}
