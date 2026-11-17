//
//  ConfigService.swift
//  GeorgiaTechApp
//
//  Created by Brayden Huguenard on 4/9/26.
//

import Firebase
import FirebaseAuth
import Foundation

actor ConfigService {
    static let shared = ConfigService()
    private var config: [String: String] = [:]
    private var hasFetched = false
    private var fetchTask: Task<Void, Never>?
    
    func fetchIfNeeded() async {
        guard !hasFetched else { return }
        
        if let fetchTask {
            await fetchTask.value
            return
        }
        
        let task = Task { await self.fetch() }
        fetchTask = task
        await task.value
        fetchTask = nil
    }
    func fetch() async {
        do {
            guard let token = try await Auth.auth().currentUser?.getIDToken() else {
#if DEBUG
                print("ConfigService: no Firebase user")
#endif
                return
            }
            var request = await URLRequest(url: try APIUtility.url(for: "config/"))
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            let (data, response) = try await URLSession.shared.data(for: request)
            try validateHTTPResponse(response)
            
            let fetchedConfig = try JSONDecoder().decode(
                [String: String].self, from: data)
            config = fetchedConfig
            hasFetched = true
#if DEBUG
            print("ConfigService: loaded \(config.count) keys")
#endif
        } catch {
#if DEBUG
            print("ConfigService fetch failed: \(error.localizedDescription)")
#endif
        }
    }
    
    func key(_ name: String) -> String? {
        config[name]
    }
    
    private func validateHTTPResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode)
        else { throw URLError(.badServerResponse) }
    }
    
    // Can call with
    // let url = await ConfigService.shared.key("dining_url")
    // dining_url, capacity_url, printer_url, microwave_url, map_url, metadata_url
}
