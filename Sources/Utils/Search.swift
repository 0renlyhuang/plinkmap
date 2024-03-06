//
//  Search.swift
//  parse_link_file
//
//  Created by renly on 2024/1/27.
//

import Foundation

func simpleSearch(for address: UInt64, in sections: [SectionDetail], from index: Int) -> Int? {
    for i in index..<sections.count {
        let section = sections[i]
        if address >= section.addressStart && address <= section.addressStart + section.size {
            return i
        }
    }
    
    return nil
}

func binarySearch(for address: UInt64, in sections: [SectionDetail]) -> Int? {
    var low = 0
    var high = sections.count - 1
    
    while low <= high {
        let mid = (low + high) / 2
        let section = sections[mid]
        
        if address >= section.addressStart && address <= section.addressStart + section.size {
            return mid  // 找到所属的区间
        } else if address < section.addressStart {
            high = mid - 1
        } else {
            low = mid + 1
        }
    }
    
    return nil  // 所属的区间不存在
}
