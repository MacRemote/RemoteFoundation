//
//  OS_X_Tests.swift
//  OS X Tests
//
//  Created by Tom Hu on 7/15/15.
//
//

import Cocoa
import XCTest

class OS_X_Tests: XCTestCase {

    var client: MRRemoteControlClient!
    var server: MRRemoteControlServer!

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.

        self.client = MRRemoteControlClient.sharedClient
        self.server = MRRemoteControlServer.sharedServer
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()

        self.client = nil
        self.server = nil
    }

    func testConnection() {
        // This is an example of a functional test case.
        XCTAssert(true, "Pass")
        
        self.server.startBroadCasting()

        self.client.connectToService(self.server.service)

        let dataStr = "ewtwet"
        
        self.client.send(dataStr.dataUsingEncoding(NSUTF8StringEncoding))
        
        self.client.disconnect()

        self.server.stopBroadCasting()
    }

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measureBlock() {
            // Put the code you want to measure the time of here.
        }
    }

}
