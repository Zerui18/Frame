//
//  DiggerHelper.swift
//  Digger
//
//  Created by ant on 2017/10/26.
//  Copyright © 2017年 github.cornerant. All rights reserved.
//

import Foundation

// MARK:-  result help

public enum DiggerResult<T> {
    case failure(Error)
    case success(T)
    
}
// MARK:-  error help


public let DiggerErrorDomain = "com.github.cornerAnt.DiggerErrorDomain"
public enum DiggerError: Int {
    
    case badURL = 9981
    case fileIsExist = 9982
    case fileInfoError = 9983
    case invalidStatusCode = 9984
    case diskOutOfSpace = 9985
    case downloadCanceled = -999
    
}



// MARK:-  error help
public enum LogLevel {
    case high,low,none
}

public func diggerLog<T>(_ info: T, file: NSString = #file, method: String = #function, line: Int = #line){
    
    switch  DiggerManager.shared.logLevel  {
        
        case .none:
            _ = ""
    
        case .low:
            print("***************DiggerLog****************")
            print("\(info)" + "\n")
    
        case .high:
            print("***************DiggerLog****************")
            print(   "file   : " + "\(file.lastPathComponent)" + "\n"
                + "method : " + "\(method)" + "\n"
                + "line   : "   + "[\(line)]:"  + "\n"
                + "info   : "   +  "\(info)"
            )
    }
    
    
}


// MARK:- url helper

public protocol DiggerURL {
    
    func asURL() throws -> URL
}

extension String: DiggerURL {
    
    public func asURL() throws -> URL {
        guard let url = URL(string: self) else { throw    NSError(domain: DiggerErrorDomain, code: DiggerError.badURL.rawValue, userInfo: ["url":self]) }
        return url
    }
}

extension URL: DiggerURL {
    public func asURL() throws -> URL {
        
        return self
        
    }
}

