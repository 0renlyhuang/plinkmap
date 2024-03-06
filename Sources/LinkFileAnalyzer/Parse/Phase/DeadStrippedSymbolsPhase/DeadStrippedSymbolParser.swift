//
//  DeadStrippedSymbolParser.swift
//  parse_link_file
//
//  Created by renly on 2024/1/21.
//

import Foundation

class DeadStrippedSymbolParser : ConcurrentParser {
    private let context: LinkFileParseContext
    private let linkFileName: String
    private let targetIndexSet: Set<Int>
    
    private lazy var deadSymbolQueue: DispatchQueue = {
        let linkFileName = self.context.linkFileInfo.linkFileName
        let queue = DispatchQueue(label: "parse_dead_symbol_main_\(linkFileName)_\(currentNanoTimestamp())");
        return queue
    }()
    
    init(context: LinkFileParseContext) {
        self.context = context
        self.linkFileName = self.context.linkFileInfo.linkFileName
        self.targetIndexSet = Set(self.context.runningContext.index2ObjDetailMap.keys)
        
        super.init(
            dispatchQueueLabel: "parse_dead_symbol_concurrent_\(self.linkFileName)_\(currentNanoTimestamp())",
            maxLineCountInOneTask: 10,
            maxConcurrencyCount: 10,
            isNewLine: { line in line.hasPrefix("<<") }
        )
    }
    
    private struct SymboSizeInfo {
        let index: Int
        let symbolSize: UInt64
        let symbolName: String
    }
    
    override func consumeLines(_ lines: [String], _ waitTaskGroup: DispatchGroup) {
//        # Dead Stripped Symbols:
//        #            Size        File  Name
//        <<dead>>     0x0000001C    [  1] Name
//        <<dead>>     0x00000060    [  2] Name
        
        
        var symboSizeInfoList = [SymboSizeInfo]()
        var linesForASymbol = [String]()
        
        let parseLastSymbol = {
            if (linesForASymbol.isEmpty) {
                return
            }
            
            if let symbolSizeInfo = self.parseASymbol(linesForASymbol) {
                symboSizeInfoList.append(symbolSizeInfo)
            }
            linesForASymbol = [String]()
        }
        
        for i in 0...lines.count {
            if (i == lines.count) {
                parseLastSymbol()
                break
            }
            
            let line = lines[i]
            let isNewLine = line.hasPrefix("<<")
            if (isNewLine) {
                parseLastSymbol()
            }
            
            linesForASymbol.append(line)
        }
        
        if (symboSizeInfoList.isEmpty) {
            return
        }
        
        waitTaskGroup.enter()
        self.deadSymbolQueue.async {
            self.saveResult(symboSizeInfoList)
            waitTaskGroup.leave()
        }
        
    }
    
    
    
    // a symbol could be multilines
    private func parseASymbol(_ lines: [String]) -> SymboSizeInfo? {
        guard let firstLine = lines.first else {
            assert(false)
            return nil
        }
        
        
        let substrings = firstLine.split(separator: "\t", maxSplits: 2)
        guard substrings.count == 3 else {
            assert(false)
            return nil
        }
        
        let fileAndName = substrings[2].split(separator: "] ", maxSplits: 1)
        guard fileAndName.count >= 2 else {
            assert(false)
            return nil
        }
        
        // get index
        guard fileAndName[0].hasPrefix("[") else {
            assert(false)
            return nil
        }

        let indexString = fileAndName[0].dropFirst().trimmingCharacters(in: .whitespaces)
        guard let index = Int(indexString) else {
            assert(false)
            return nil
        }

        // symbol is not belonged to wanted object
        guard (self.targetIndexSet.contains(index)) else {
            return nil
        }

        // get size
        guard let size = convertHexToUint64(String(substrings[1])) else {
            assert(false)
            return nil
        }

//        let symboleNameInFirstLine = fileAndName[1...].map { String($0) }.joined()
        let symboleNameInFirstLine = String(fileAndName[1])
        let symboleName = ([symboleNameInFirstLine] + lines[1...]).map { String($0) }.joined(separator: "\n")
        return SymboSizeInfo(index: index, symbolSize: size, symbolName: symboleName)
    }
    
    private func saveResult(_ symboSizeInfoList: [SymboSizeInfo]) {
        for symboSizeInfo in symboSizeInfoList {
            let idnex = symboSizeInfo.index
            let symbolName = symboSizeInfo.symbolName
            let symbolSize = symboSizeInfo.symbolSize
            
            self.context.runningContext.index2ObjDetailMap[idnex]?.objDeadSymbolSize += symbolSize
            self.context.runningContext.index2ObjDetailMap[idnex]?.symbolDetailList.append(
                SymbolDetail(symbolName: symbolName, symbolSize: symbolSize, isDead: true, sectionDetail: nil)
            )
        }
    }
}
