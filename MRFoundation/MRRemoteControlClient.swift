//
//  MRRemoteControlClient.swift
//  Remote Foundation
//
//  Created by Tom Hu on 6/13/15.
//  Copyright (c) 2015 Tom Hu. All rights reserved.
//

import Foundation
import CocoaAsyncSocket

// TODO: Consider about handling disconnection/error

// MARK: - Client Delegate Protocol

@objc public protocol MRRemoteControlClientDelegate {
    @objc optional func remoteControlClientDidChangeServices(services: Array<NSNetService>)
    
    @objc optional func remoteControlClientWillConnectToService(service: NSNetService, onSocket socket: GCDAsyncSocket)
    @objc optional func remoteControlClientDidConnectToService(service: NSNetService, onSocket socket: GCDAsyncSocket)
    
    @objc optional func remoteControlClientDidSendData(data: NSData, toService service: NSNetService, onSocket socket: GCDAsyncSocket)
    
    @objc optional func remoteControlClientDidReceiveData(data: NSData, fromService service: NSNetService, onSocket socket: GCDAsyncSocket)
}

// MARK: - Client

public class MRRemoteControlClient: NSObject, NSNetServiceBrowserDelegate, NSNetServiceDelegate, GCDAsyncSocketDelegate {
    
    // MARK: - Singleton
    
    public class var sharedClient: MRRemoteControlClient {
        struct Static {
            static let client: MRRemoteControlClient = MRRemoteControlClient()
        }
        return Static.client
    }
    
    public weak var delegate: MRRemoteControlClientDelegate?
    private var serviceBrowser: NSNetServiceBrowser!
    private(set) var connectedService: NSNetService?
    private(set) var services: Array<NSNetService>!
    private(set) var connectedSocket: GCDAsyncSocket?
    
    // MARK: - Life Circle
    
    private override init() {
        super.init()
        
        self.services = []
    }
    
    public func startSearch() {
        println("Searching services...")
        if self.services != nil {
            self.services.removeAll(keepCapacity: true)
        }
        
        self.serviceBrowser = NSNetServiceBrowser()
        self.serviceBrowser.delegate = self
        self.serviceBrowser.searchForServicesOfType("_macremote._tcp.", inDomain: "local.")
    }
    
    public func stopSearch() {
        if self.serviceBrowser != nil {
            self.serviceBrowser.stop()
            self.serviceBrowser.delegate = nil
            self.serviceBrowser = nil
            
            // FIXME: Disconnected
            self.connectedSocket?.disconnect()
            self.connectedService = nil
        }
    }
    
    public func connectToService(service: NSNetService) {
        service.delegate = self
        service.resolveWithTimeout(10)
    }
    
    private func connectToServerWithService(service: NSNetService) -> Bool {
        var isConnected = false
        
        let addresses: Array = service.addresses!
        
        if let _connected = self.connectedSocket?.isConnected {
            isConnected = self.connectedSocket!.isConnected
        } else {
            // Initialize Socket
            self.connectedSocket = GCDAsyncSocket(delegate: self, delegateQueue: dispatch_get_main_queue())
            
            // Connect
            while !isConnected && Bool(addresses.count) {
                let address: NSData = addresses[0] as NSData
                var error: NSError?
                
                if (self.connectedSocket?.connectToAddress(address, error: &error) != nil) {
                    self.connectedService = service
                    isConnected = true
                } else if error != nil {
                    // Error handle
                    println("Unable to connect to address.\nError \(error?) with user info \(error?.userInfo)")
                }
            }
        }
        
        return isConnected
    }
    
    private func parseHeader(data: NSData) -> UInt {
        var out: UInt = 0
        data.getBytes(&out, length: sizeof(UInt))
        return out
    }
    
    public func send(data: NSData) {
        println("Sending data to server!")
        
        var header = data.length
        let headerData = NSData(bytes: &header, length: sizeof(UInt))
        
        self.connectedSocket?.writeData(headerData, withTimeout: -1.0, tag: PacketTag.Header.rawValue)
        self.connectedSocket?.writeData(data, withTimeout: -1.0, tag: PacketTag.Body.rawValue)
        
        self.delegate?.remoteControlClientDidSendData?(data, toService: self.connectedService!, onSocket: self.connectedSocket!)
    }
    
    // MARK: - NSNetServiceBrowserDelegate
    
    public func netServiceBrowserWillSearch(aNetServiceBrowser: NSNetServiceBrowser) {
        println("Will search service")
    }
    
    public func netServiceBrowser(aNetServiceBrowser: NSNetServiceBrowser, didFindService aNetService: NSNetService, moreComing: Bool) {
        println("Find a service: \(aNetService.name)")
        println("Port: \(aNetService.port)")
        println("Domain: \(aNetService.domain)")
        
        self.services.append(aNetService)
        if !moreComing {
            self.delegate?.remoteControlClientDidChangeServices?(self.services)
        }
    }
    
    public func netServiceBrowser(aNetServiceBrowser: NSNetServiceBrowser, didRemoveService aNetService: NSNetService, moreComing: Bool) {
        println("Remove a service: \(aNetService.name)")
        
        // FIXME: Disconnected
//        if self.connectedService == aNetService {
//            self.connectedSocket?.disconnect()
//            self.connectedService = nil
//            
//            UIApplication.sharedApplication().keyWindow?.rootViewController?.navigationController?.popToRootViewControllerAnimated(true)
//        }
        
        self.services.removeObject(aNetService)
        if !moreComing {
            self.delegate?.remoteControlClientDidChangeServices?(self.services)
        }
    }
    
    public func netServiceBrowserDidStopSearch(aNetServiceBrowser: NSNetServiceBrowser) {
        println("Stop search!")
        
        self.stopSearch()
    }
    
    public func netServiceBrowser(aNetServiceBrowser: NSNetServiceBrowser, didNotSearch errorDict: [NSObject : AnyObject]) {
        println("Start search...")
        
        self.startSearch()
    }
    
    // MARK: - NSNetServiceDelegate
    
    public func netServiceDidResolveAddress(sender: NSNetService) {
        println("Did resolve address: \(sender.addresses)")
        
        if self.connectToServerWithService(sender) {
            println("Connecting to \(sender.name)")
        }
    }
    
    public func netService(sender: NSNetService, didNotResolve errorDict: [NSObject : AnyObject]) {
        println("Did not resolve.\n Error: \(errorDict)")
    }
    
    // MARK: - GCDAsyncSocketDelegate
    
    public func socket(sock: GCDAsyncSocket!, didConnectToHost host: String!, port: UInt16) {
        println("Connected to host: \(host)")
        println("Port: \(port)")
        
        self.delegate?.remoteControlClientDidConnectToService?(self.connectedService!, onSocket: self.connectedSocket!)
        
        sock.readDataToLength(UInt(sizeof(UInt)), withTimeout: -1.0, tag: PacketTag.Header.rawValue)
    }
    
    public func socketDidDisconnect(sock: GCDAsyncSocket!, withError err: NSError!) {
        println("Socket did disconnect \(sock), error: \(err)")
    }
    
    public func socket(sock: GCDAsyncSocket!, didReadData data: NSData!, withTag tag: Int) {
        println("Read data")
        
        if self.connectedSocket == sock {
            if data.length == sizeof(UInt) {
                // Header
                let bodyLength: UInt = self.parseHeader(data)
                
                sock.readDataToLength(bodyLength, withTimeout: -1.0, tag: PacketTag.Body.rawValue)
            } else {
                // Body
                self.delegate?.remoteControlClientDidReceiveData?(data, fromService: self.connectedService!, onSocket: self.connectedSocket!)
                
                sock.readDataToLength(UInt(sizeof(UInt)), withTimeout: -1.0, tag: PacketTag.Header.rawValue)
            }
        }
    }
    
    public func socketDidCloseReadStream(sock: GCDAsyncSocket!) {
        println("Closed read stream.")
    }
    
}
