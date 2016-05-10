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

    @objc optional func remoteControlClientDidDisonnect()

    @objc optional func remoteControlClientDidSendData(data: NSData, toService service: NSNetService, onSocket socket: GCDAsyncSocket)

    @objc optional func remoteControlClientDidReceiveData(data: NSData, fromService service: NSNetService, onSocket socket: GCDAsyncSocket)
}

// MARK: - Client

public class MRRemoteControlClient: NSObject, NSNetServiceBrowserDelegate, NSNetServiceDelegate, GCDAsyncSocketDelegate {
    
    // MARK: - Singleton
    
    public static let sharedClient: MRRemoteControlClient = MRRemoteControlClient()
    
    // MARK: - Delegate

    public weak var delegate: MRRemoteControlClientDelegate?

    // MARK: Member Variables

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
        print("Searching services...")
        if self.services != nil {
            self.services.removeAll(keepCapacity: true)
        }
        
        self.serviceBrowser = NSNetServiceBrowser()
        self.serviceBrowser.delegate = self
        self.serviceBrowser.searchForServicesOfType("_macremote._tcp.", inDomain: "local.")
    }
    
    public func stopSearch() {
        print("Stop search services!")
        if self.serviceBrowser != nil {
            self.serviceBrowser.stop()
            self.serviceBrowser.delegate = nil
            self.serviceBrowser = nil
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
            isConnected = _connected
        } else {
            // Initialize Socket
            self.connectedSocket = GCDAsyncSocket(delegate: self, delegateQueue: dispatch_get_main_queue())
            
            // Connect
            while !isConnected && Bool(addresses.count) {
                let address: NSData = addresses[0]

                do {
                    let ret = try self.connectedSocket?.connectToAddress(address) // ???: 怎么突然没有返回值了
                    if ret != nil {
                        self.connectedService = service
                        isConnected = true
                    }
                    
                } catch let error as NSError {
                    // Error handle
                    print("Unable to connect to address.\nError \(error) with user info \(error.userInfo)")
                }
            }
        }
        
        return isConnected
    }
    
    public func disconnect() {
        print("Disconnect")
        self.connectedService?.stop()
        self.connectedService?.delegate = nil
        self.connectedService = nil
        
        self.connectedSocket?.disconnect()
        self.connectedSocket?.delegate = nil
        self.connectedSocket = nil
    }
    
    public func send(data: NSData) {
        print("Sending data to server!")
        
        var header = data.length
        let headerData = NSData(bytes: &header, length: sizeof(MRHeaderSizeType))
        
        // Send Header
        self.connectedSocket?.writeData(headerData, withTimeout: -1.0, tag: MRPacketTag.Header.rawValue)
        
        // Send Body
        self.connectedSocket?.writeData(data, withTimeout: -1.0, tag: MRPacketTag.Body.rawValue)
        
        self.delegate?.remoteControlClientDidSendData?(data, toService: self.connectedService!, onSocket: self.connectedSocket!)
    }
    
    // MARK: - NSNetServiceBrowserDelegate
    
    public func netServiceBrowserWillSearch(aNetServiceBrowser: NSNetServiceBrowser) {
        print("Will search service")
    }
    
    public func netServiceBrowser(aNetServiceBrowser: NSNetServiceBrowser, didFindService aNetService: NSNetService, moreComing: Bool) {
        print("Find a service: \(aNetService.name)")
        print("Port: \(aNetService.port)")
        print("Domain: \(aNetService.domain)")
        
        self.services.append(aNetService)
        if !moreComing {
            self.delegate?.remoteControlClientDidChangeServices?(self.services)
        }
    }
    
    public func netServiceBrowser(aNetServiceBrowser: NSNetServiceBrowser, didRemoveService aNetService: NSNetService, moreComing: Bool) {
        print("Remove a service: \(aNetService.name)")
        
        self.services.removeObject(aNetService)
        if !moreComing {
            self.delegate?.remoteControlClientDidChangeServices?(self.services)
        }
    }
    
    public func netServiceBrowserDidStopSearch(aNetServiceBrowser: NSNetServiceBrowser) {
        print("Stop search!")
    }
    
    public func netServiceBrowser(aNetServiceBrowser: NSNetServiceBrowser, didNotSearch errorDict: [String : NSNumber]) {
        print("Search unsuccessfully!")
        print("Restart searching...")
        
        // Stop
        self.stopSearch()
        
        // Restart
        self.startSearch()
    }
    
    // MARK: - NSNetServiceDelegate
    
    public func netServiceDidResolveAddress(sender: NSNetService) {
        print("Did resolve address: \(sender.addresses)")
        
        if self.connectToServerWithService(sender) {
            print("Connecting to \(sender.name)")
        }
    }
    
    public func netService(sender: NSNetService, didNotResolve errorDict: [String : NSNumber]) {
        print("Did not resolve.\n Error: \(errorDict)")
    }
    
    // MARK: - GCDAsyncSocketDelegate
    
    public func socket(sock: GCDAsyncSocket!, didConnectToHost host: String!, port: UInt16) {
        print("Connected to host: \(host)")
        print("Port: \(port)")
        
        self.delegate?.remoteControlClientDidConnectToService?(self.connectedService!, onSocket: self.connectedSocket!)
        
        // Stop search
        // self.stopSearch()
        
        // Read Header
        sock.readDataToLength(UInt(sizeof(MRHeaderSizeType)), withTimeout: -1.0, tag: MRPacketTag.Header.rawValue)
    }
    
    public func socketDidDisconnect(sock: GCDAsyncSocket!, withError err: NSError!) {
        print("Socket did disconnect \(sock), error: \(err)")
        
        if err != nil {
            // Disconnect
            self.disconnect()
            
            // Nofify delegate
            self.delegate?.remoteControlClientDidDisonnect?()
        }
    }
    
    public func socket(sock: GCDAsyncSocket!, didReadData data: NSData!, withTag tag: Int) {
        print("Read data")
        
        if self.connectedSocket == sock {
            if data.length == sizeof(MRHeaderSizeType) {
                // Header
                let bodyLength: MRHeaderSizeType = parseHeader(data)
                
                sock.readDataToLength(UInt(bodyLength), withTimeout: -1.0, tag: MRPacketTag.Body.rawValue)
            } else {
                // Body
                self.delegate?.remoteControlClientDidReceiveData?(data, fromService: self.connectedService!, onSocket: self.connectedSocket!)
                
                sock.readDataToLength(UInt(sizeof(MRHeaderSizeType)), withTimeout: -1.0, tag: MRPacketTag.Header.rawValue)
            }
        }
    }
    
    public func socketDidCloseReadStream(sock: GCDAsyncSocket!) {
        print("Closed read stream.")
    }
    
}
