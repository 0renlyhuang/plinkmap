//
//  SectionParser.swift
//  parse_link_file
//
//  Created by renly on 2024/1/25.
//

import Foundation

class SectionParser {
    private let context: LinkFileParseContext
    
    init(context: LinkFileParseContext) {
        self.context = context
    }
    
    func handleLine(_ line: String) {
//        # Sections:
//        # Address    Size        Segment    Section
//        0x00008000    0x0E2C5608    __TEXT    __text
//        0x0E2CD608    0x0000D530    __TEXT    __stubs
        
        let substrings = line.split(separator: "\t", maxSplits: 3)
        guard substrings.count == 4 else {
            assert(false)
            return
        }
        
        guard let address = convertHexToUint64(String(substrings[0])) else {
            assert(false)
            return
        }
        
        guard let size = convertHexToUint64(String(substrings[1])) else {
            assert(false)
            return
        }
        
        let segment = String(substrings[2])
        let section = String(substrings[3])
        
        self.context.runningContext.sortedSectionDetail.append(SectionDetail(addressStart: address, size: size, segament: segment, section: section))
    }
}
