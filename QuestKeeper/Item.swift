//
//  Item.swift
//  QuestKeeper
//
//  Created by Dongmin yu on 7/8/26.
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
