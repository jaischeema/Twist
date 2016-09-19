//
//  Logger.swift
//  Twist
//
//  Created by Jais Cheema on 19/09/2016.
//  Copyright © 2016 Needle Apps. All rights reserved.
//

import Foundation

public protocol TwistLogger {
    func twistDebug(_ message: String)
    func twistInfo(_ message: String)
    func twistError(_ message: String)
}

public extension TwistLogger {
    func twistDebug(_ message: String) {
        print("Twist: \(message)")
    }

    func twistInfo(_ message: String) {
        print("Twist: \(message)")
    }

    func twistError(_ message: String) {
        print("Twist: \(message)")
    }
}

class DefaultTwistLogger: TwistLogger {}
