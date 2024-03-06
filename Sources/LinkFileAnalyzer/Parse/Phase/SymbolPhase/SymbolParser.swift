import Foundation

class SymbolParser : ConcurrentParser {
    private let context: LinkFileParseContext
    private let linkFileName: String
    private let targetIndexSet: Set<Int>
    private let sortedSectionDetail: [SectionDetail]

    
    private lazy var symbolQueue: DispatchQueue = {
        let linkFileName = self.context.linkFileInfo.linkFileName
        let queue = DispatchQueue(label: "parse_symbol_main_\(linkFileName)_\(currentNanoTimestamp())");
        return queue
    }()
    
    init(context: LinkFileParseContext) {
        self.context = context
        self.linkFileName = self.context.linkFileInfo.linkFileName
        self.targetIndexSet = Set(self.context.runningContext.index2ObjDetailMap.keys)
        self.sortedSectionDetail = self.context.runningContext.sortedSectionDetail
        
        super.init(
            dispatchQueueLabel: "parse_symbol_concurrent_\(self.linkFileName)_\(currentNanoTimestamp())",
            maxLineCountInOneTask: 10,
            maxConcurrencyCount: 10,
            isNewLine: { (line : String) in line.hasPrefix("0x") }
        )
    }
    
    private struct SymboSizeInfo {
        let index: Int
        let symbolSize: UInt64
        let symbolName: String
        let sectionDetail: SectionDetail
    }
    
    override func consumeLines(_ lines: [String], _ waitTaskGroup: DispatchGroup) {
//                # Symbols:
//                # Address    Size        File  Name
//                0x00008000    0x00000004    [21325] +[ClassName func]    <- start form this line
//                0x00008004    0x00000054    [21325] _aFunc
        
        
        var symboSizeInfoList = [SymboSizeInfo]()
        var lastSectionIndex: Int?
        var linesForASymbol = [String]()
        
        let parseLastSymbol = {
            if (linesForASymbol.isEmpty) {
                return
            }
            if let symbolSizeInfo = self.parseASymbol(linesForASymbol, &lastSectionIndex) {
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
            let isNewLine = line.hasPrefix("0x")
            if (isNewLine) {
                parseLastSymbol()
            }
            
            linesForASymbol.append(line)
        }
        
        if (symboSizeInfoList.isEmpty) {
            return
        }
        
        
        waitTaskGroup.enter()
        self.symbolQueue.async {
            self.saveResult(symboSizeInfoList)
            waitTaskGroup.leave()
        }
        
    }
    
    // a symbol could be multilines
    private func parseASymbol(_ lines: [String], _ lastSectionIndex: inout Int?) -> SymboSizeInfo? {
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
        guard fileAndName.count == 2 else {
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
        
        
        guard let address = convertHexToUint64(String(substrings[0])) else {
            assert(false)
            return nil
        }
        
        
        if let lastIndex = lastSectionIndex {
            lastSectionIndex = simpleSearch(for: address, in: self.sortedSectionDetail, from: lastIndex)
        }
        else {
            lastSectionIndex = binarySearch(for: address, in: self.sortedSectionDetail)
        }
        
        guard let lastIndex = lastSectionIndex else {
            assert(false)
            return nil
        }
        
        let sectionDetail = self.sortedSectionDetail[lastIndex]
        if (sectionDetail.section == "__bss" || sectionDetail.section == "__common") {
            return nil
        }
        
//        let symboleNameInFirstLine = fileAndName[1...].map { String($0) }.joined()
        let symboleNameInFirstLine = String(fileAndName[1])
        let symboleName = ([symboleNameInFirstLine] + lines[1...]).map { String($0) }.joined(separator: "\n")
        
        return SymboSizeInfo(index: index,symbolSize: size, symbolName: symboleName, sectionDetail:sectionDetail)
    }
    
    private func saveResult(_ symboSizeInfoList: [SymboSizeInfo]) {
        for symboSizeInfo in symboSizeInfoList {
            let idnex = symboSizeInfo.index
            let symbolName = symboSizeInfo.symbolName
            let symbolSize = symboSizeInfo.symbolSize
            
            self.context.runningContext.index2ObjDetailMap[idnex]?.objUsingSymbolSize += symbolSize
            self.context.runningContext.index2ObjDetailMap[idnex]?.symbolDetailList.append(
                SymbolDetail(symbolName: symbolName, symbolSize: symbolSize, isDead: false, sectionDetail: symboSizeInfo.sectionDetail)
            )
        }
    }
    
}
