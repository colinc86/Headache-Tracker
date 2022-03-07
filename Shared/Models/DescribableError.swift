//
//  DescribableError.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/7/22.
//

import Foundation

/// An error that implements a description.
protocol DescribableError: CustomStringConvertible, Error {}
