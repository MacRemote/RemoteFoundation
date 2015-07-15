//
//  Array+removeObject.swift
//  MacRemote iOS
//
//  Created by Tom Hu on 6/13/15.
//  Copyright (c) 2015 Tom Hu. All rights reserved.
//

import Foundation

extension Array {
    mutating func removeObject<U: Equatable>(object: U) {
        var index: Int?
        for (idx, objectToCompare) in enumerate(self) {
            if let to = objectToCompare as? U {
                if object == to {
                    index = idx
                }
            }
        }
        
        if index != nil {
            self.removeAtIndex(index!)
        }
    }
}
