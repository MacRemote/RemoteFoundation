//
//  MREvent.swift
//  Remote Foundation
//
//  Created by Tom Hu on 6/16/15.
//  Copyright (c) 2015 Tom Hu. All rights reserved.
//

import Foundation

public enum MREventType: Int {
    // Sound
    case SoundUp
    case SoundDown
    case SoundMute
    
    // Mouse
    case LeftMouseDown
    case LeftMouseUp
    case RightMouseDown
    case RightMouseUp
    case MouseClick
    
    // Keyboard
    case KeyDown
    case KeyUp
    
    // Brightness
    case BrightnessLighten
    case BrightnessDarken
    
    // Zoom
    case ZoomIn
    case ZoomOut
}

public class MREvent: NSObject, NSCoding, NSSecureCoding, Printable {
    
    public var eventType: MREventType!
    public var message: String! = ""
    
    public var data: NSData? {
        get {
            return NSKeyedArchiver.archivedDataWithRootObject(self)
        }
    }
    
    public convenience init(eventType: MREventType, message: String) {
        self.init()
        
        self.eventType = eventType
        self.message = message
    }
    
    public convenience init?(data: NSData) {
        self.init()
        
        if let eventData = NSKeyedUnarchiver.unarchiveObjectWithData(data) as? MREvent {
            self.eventType = eventData.eventType
            self.message = eventData.message
        }
    }
    
    // MARK: - NSCoding
    
    public required convenience init(coder aDecoder: NSCoder) {
        self.init()
        
        self.eventType = MREventType(rawValue: aDecoder.decodeIntegerForKey("eventType"))
        self.message = aDecoder.decodeObjectForKey("message") as? String
    }
    
    public func encodeWithCoder(aCoder: NSCoder) {
        aCoder.encodeInteger(self.eventType.rawValue, forKey: "eventType")
        aCoder.encodeObject(self.message, forKey: "message")
    }
    
    // MARK: - NSSecureCoding
    
    public class func supportsSecureCoding() -> Bool {
        return true
    }
    
    // MARK: - Description
    
    public override var description: String {
        get {
            return "Event Type: \(self.eventType.rawValue)\nMessage: \(self.message)"
        }
    }
    
}
