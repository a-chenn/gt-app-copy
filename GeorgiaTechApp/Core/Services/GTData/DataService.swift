//
//  DataService.swift
//  GeorgiaTechApp
//
//  Created by Brayden Huguenard on 7/10/26.
//

import Foundation
import SwiftData

@Observable @MainActor final class DataService {
    private var hasSynced = false
    
    func sync(context: ModelContext) async {
        guard !hasSynced else { return }
        
        hasSynced = true
        
        await GTDataService.shared.syncAll(context: context)
    }
}
