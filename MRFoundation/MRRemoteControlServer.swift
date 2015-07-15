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

#if TARGET_OS_IPHONE
import UIKit
#endif

enum PacketTag: Int {
    case Header = 1
    case Body = 2
}

// MARK: - Server Delegate Protocol

// TODO: Complete this protocol
@objc public protocol MRRemoteControlServerDelegate {
    @objc optional func remoteControlServerDidReceiveEvent(event: MREvent)
}

public class MRRemoteControlServer: NSObject, NSNetServiceDelegate, GCDAsyncSocketDelegate {
    
    // MARK: - Singleton
    
    public class var sharedServer: MRRemoteControlServer {
        struct Static {
            static let server: MRRemoteControlServer = MRRemoteControlServer()
        }
        return Static.server
    }
    
    public weak var delegate: MRRemoteControlServerDelegate?
    private var service: NSNetService!
    private var socket: GCDAsyncSocket!
    
    // MARK: - Life Circle

    private override init() {
        super.init()
    }
    
    public func startBroadCasting() {
        self.socket = GCDAsyncSocket(delegate: self, delegateQueue: dispatch_get_main_queue())
        
        var error: NSError?
        if self.socket.acceptOnPort(0, error: &error) {
            var deviceName: String = "Default Name"
            
            #if os(iOS)
                deviceName = UIDevice.currentDevice().name
            #elseif os(OSX)
                if let name = NSHost.currentHost().name {
                    deviceName = name
                }
            #endif
            
            self.service = NSNetService(domain: "local.", type: "_macremote._tcp.", name: deviceName, port: Int32(self.socket.localPort))
            self.service.delegate = self
            self.service.publish()
        } else {
            println("Unable to create socket. Error \(error)")
        }
    }
    
    private func parseHeader(data: NSData) -> UInt {
        var out: UInt = 0
        data.getBytes(&out, length: sizeof(UInt))
        return out
    }
    
    // MARK: - GCDAsyncSocketDelegate
    
    public func socket(sock: GCDAsyncSocket!, didAcceptNewSocket newSocket: GCDAsyncSocket!) {
        println("Accepted new socket")
        self.socket = newSocket
        self.socket.readDataToLength(UInt(sizeof(UInt)), withTimeout: -1.0, tag: PacketTag.Header.rawValue)
    }
    
    public func socketDidDisconnect(sock: GCDAsyncSocket!, withError err: NSError!) {
        println("Disconnected: error \(err)")
    }
    
    public func socket(sock: GCDAsyncSocket!, didReadData data: NSData!, withTag tag: Int) {
        println("Read data")
        
        if data.length == sizeof(UInt) {
            // Header
            let bodyLength: UInt = self.parseHeader(data)
            sock.readDataToLength(bodyLength, withTimeout: -1, tag: PacketTag.Body.rawValue)
        } else {
            // Body
            if let body = NSString(data: data, encoding: NSUTF8StringEncoding) {
                println("Body: \(body)")
                
                // Handle ios notification
                
            } else if let event = MREvent(data: data) {
                println("Event: \(event)")
                
                // Handle event
                self.delegate?.remoteControlServerDidReceiveEvent?(event)
            }
            
            sock.readDataToLength(UInt(sizeof(UInt)), withTimeout: -1, tag: PacketTag.Header.rawValue)
        }
    }
    
    public func socket(sock: GCDAsyncSocket!, didWriteDataWithTag tag: Int) {
        println("Wrote data with tag: \(tag)")
    }
    
    // MARK: NSNetServiceDelegate
    
    public func netServiceWillPublish(sender: NSNetService) {
        println("Net Service Will Publish!")
    }
    
    public func netServiceDidPublish(sender: NSNetService) {
        println("Net Service Did Publish!")
        println("Service Name: \(sender.name)")
        println("Port: \(sender.port)")
    }
    
    public func netService(sender: NSNetService, didNotPublish errorDict: [NSObject : AnyObject]) {
        println("Net Service Did Not Publish!")
        println("Error: \(errorDict)")
    }
    
    public func netServiceWillResolve(sender: NSNetService) {
        println("Net Service Will Resolve!")
    }
    
    public func netServiceDidResolveAddress(sender: NSNetService) {
        println("Net Service Did Resolve Address!")
        println("Sender: \(sender)")
    }
    
    public func netService(sender: NSNetService, didNotResolve errorDict: [NSObject : AnyObject]) {
        println("Net Service Did Not Resolve!")
        println("Error: \(errorDict)")
    }
    
    public func netServiceDidStop(sender: NSNetService) {
        println("Net Service Did Stop!")
    }
    
    public func netService(sender: NSNetService, didUpdateTXTRecordData data: NSData) {
        println("Net Service Did Update TXT Record Data!")
        println("Data: \(data)")
    }
    
    public func netService(sender: NSNetService, didAcceptConnectionWithInputStream inputStream: NSInputStream, outputStream: NSOutputStream) {
        println("Net Service Did Accept Connection With Input Stream!")
        println("Input Stream: \(inputStream)")
        println("Output Stream: \(outputStream)")
    }
    
}
