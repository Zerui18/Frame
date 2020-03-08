//
//  Digger.swift
//  Digger
//
//  Created by ant on 2017/10/25.
//  Copyright © 2017年 github.cornerant. All rights reserved.
//

import UIKit

public let digger = "Digger"



/// start download with url

@discardableResult
public func download(_ url: DiggerURL) -> DiggerSeed{
    
    return DiggerManager.shared.download(with: url)
    
}




