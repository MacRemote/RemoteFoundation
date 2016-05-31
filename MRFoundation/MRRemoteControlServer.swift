//
//  MRRemoteControlServer.swift
//  Remote Foundation
//
//  Created by Tom Hu on 6/13/15.
//  Copyright (c) 2015 Tom Hu. All rights reserved.
//

import Foundation
import CocoaAsyncSocket

// TODO: Consider about handling disconnection/error

#if os(iOS)
import UIKit
#endif

// MARK: - Server Delegate Protocol

// TODO: Complete this protocol
@objc public protocol MRRemoteControlServerDelegate {
    @objc optional func remoteControlServerDidReceiveEvent(event: MREvent)
}

public class MRRemoteControlServer: NSObject, NSNetServiceDelegate, GCDAsyncSocketDelegate {
    
    // MARK: - Singleton
    
    public static let sharedServer: MRRemoteControlServer = MRRemoteControlServer()

    // MARK: - Delegate

    public weak var delegate: MRRemoteControlServerDelegate?

    // MARK: - Member Variables
    private(set) var service: NSNetService!
    private(set) var socket: GCDAsyncSocket!
    
    // MARK: - Life Circle

    private override init() {
        print("Server init")
        super.init()
    }
    
    deinit {
        print("Server deinit")
        
        stopBroadCasting()
        disconnect()
    }

    public func startBroadCasting(port aPort: UInt16 = 0) {
        self.socket = GCDAsyncSocket(delegate: self, delegateQueue: dispatch_get_main_queue())
        do {
            try self.socket.acceptOnPort(aPort)
            var deviceName: String = "Default Name"

            #if os(iOS)
            deviceName = UIDevice.currentDevice().name
            #elseif os(OSX)
            if let name = NSHost.currentHost().name {
                deviceName = name
            }
            #endif

            self.service = NSNetService(domain: "", type: "_macremote._tcp.", name: "", port: Int32(self.socket.localPort))
            if #available(iOS 7.0, OSX 10.10, *) {
                print("includes peer to peer")
                self.service.includesPeerToPeer = true
            }
            self.service.delegate = self
            self.service.publish()
        } catch let error as NSError {
            print("Unable to create socket. Error \(error)")
        }
    }

    public func disconnect() {
        self.socket.disconnect()
        self.socket.delegate = nil
        self.socket = nil
    }

    public func stopBroadCasting() {
        self.service.stop()
        self.service.delegate = nil
        self.service = nil
        
        self.disconnect()
    }

    // MARK: - GCDAsyncSocketDelegate
    
    public func socket(sock: GCDAsyncSocket!, didAcceptNewSocket newSocket: GCDAsyncSocket!) {
        print("Accepted new socket")
        self.socket = newSocket
        
        // Read Header
        self.socket.readDataToLength(UInt(sizeof(MRHeaderSizeType)), withTimeout: -1.0, tag: MRPacketTag.Header.rawValue)
    }
    
    public func socketDidDisconnect(sock: GCDAsyncSocket!, withError err: NSError!) {
        print("Disconnected: error \(err)")

        if err != nil {
            self.socket = GCDAsyncSocket(delegate: self, delegateQueue: dispatch_get_main_queue())
            do {
                try self.socket.acceptOnPort(UInt16(self.service.port))
                print("Re listen")
            } catch let error as NSError {
                print("Error: \(error)")
            }
        }
    }
    
    public func socket(sock: GCDAsyncSocket!, didReadData data: NSData!, withTag tag: Int) {
//        println("Read data")
        
        if data.length == sizeof(MRHeaderSizeType) {
            // Header
            let bodyLength: MRHeaderSizeType = parseHeader(data)
            
            // Read Body
            sock.readDataToLength(UInt(bodyLength), withTimeout: -1, tag: MRPacketTag.Body.rawValue)
        } else {
            // Body
            if let body = NSString(data: data, encoding: NSUTF8StringEncoding) {
                print("Body: \(body)")
                
                // Handle ios notification
                
            } else if let event = MREvent(data: data) {
                print("Event: \(event)")
                
                // Handle event
                self.delegate?.remoteControlServerDidReceiveEvent?(event)
            }
            
            // Read Header
            sock.readDataToLength(UInt(sizeof(MRHeaderSizeType)), withTimeout: -1, tag: MRPacketTag.Header.rawValue)
        }
    }
    
    public func socket(sock: GCDAsyncSocket!, didWriteDataWithTag tag: Int) {
        print("Wrote data with tag: \(tag)")
    }
    
    // MARK: NSNetServiceDelegate
    
    public func netServiceWillPublish(sender: NSNetService) {
        print("Net Service Will Publish!")
    }
    
    public func netServiceDidPublish(sender: NSNetService) {
        print("Net Service Did Publish!")
        print("Service Name: \(sender.name)")
        print("Port: \(sender.port)")
    }
    
    public func netService(sender: NSNetService, didNotPublish errorDict: [String : NSNumber]) {
        print("Net Service Did Not Publish!")
        print("Error: \(errorDict)")
    }
    
    public func netServiceWillResolve(sender: NSNetService) {
        print("Net Service Will Resolve!")
    }
    
    public func netServiceDidResolveAddress(sender: NSNetService) {
        print("Net Service Did Resolve Address!")
        print("Sender: \(sender)")
    }
    
    public func netService(sender: NSNetService, didNotResolve errorDict: [String : NSNumber]) {
        print("Net Service Did Not Resolve!")
        print("Error: \(errorDict)")
    }
    
    public func netServiceDidStop(sender: NSNetService) {
        print("Net Service Did Stop!")
    }
    
    public func netService(sender: NSNetService, didUpdateTXTRecordData data: NSData) {
        print("Net Service Did Update TXT Record Data!")
        print("Data: \(data)")
    }
    
    public func netService(sender: NSNetService, didAcceptConnectionWithInputStream inputStream: NSInputStream, outputStream: NSOutputStream) {
        print("Net Service Did Accept Connection With Input Stream!")
        print("Input Stream: \(inputStream)")
        print("Output Stream: \(outputStream)")
    }
    
}
