//
//  fortmate.swift
//  parse_link_file
//
//  Created by renly on 2024/1/21.
//

import Foundation

func formatSize(bytes: Int64) -> String {
    let units: [String] = ["B", "KB", "MB", "GB", "TB"]

    var size = Double(bytes)
    var unitIndex = 0

    while size > 1024 && unitIndex < units.count - 1 {
        size /= 1024
        unitIndex += 1
    }

    return String(format: "%.2f %@", size, units[unitIndex])
}


func convertHexToUint64(_ hexStr: String) -> UInt64? {
    let scanner = Scanner(string: hexStr)
    
    var uint64Value: UInt64 = 0
    if scanner.scanHexInt64(&uint64Value) {
        return uint64Value
    }
    
    return nil
}
