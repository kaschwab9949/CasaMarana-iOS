//
//  Item.swift
//  Square Tier
//
//  Created by Kyle Schwab on 12/14/25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
