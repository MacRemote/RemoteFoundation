//
//  MRUtils.swift
//  Remote Foundation
//
//  Created by Tom Hu on 8/18/15.
//  Copyright (c) 2015 Tom Hu. All rights reserved.
//

import Foundation

typealias MRHeaderSizeType = UInt32

enum MRPacketTag: Int {
    case Header = 1
    case Body = 2
}

func parseHeader(data: NSData) -> MRHeaderSizeType {
    var out: MRHeaderSizeType = 0
    data.getBytes(&out, length: sizeof(MRHeaderSizeType))
    return out
}
