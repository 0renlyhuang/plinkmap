import Foundation
import Combine

func currentNanoTimestamp() -> String {
    let now = DispatchTime.now().uptimeNanoseconds
    return "\(now)"
}

struct SymbolDetail {
    let symbolName: String
    let symbolSize: UInt64
    let isDead: Bool
    let sectionDetail: SectionDetail?
}

struct ObjDetail {
    let objFilePath: String
    let userTags: [String]
    let objectFileName: String

    var objUsingSymbolSize: UInt64 = 0
    var objDeadSymbolSize: UInt64 = 0
    var symbolDetailList = [SymbolDetail]()
    
    func getSize() -> UInt64 {
        return self.objUsingSymbolSize + self.objDeadSymbolSize
    }
}

struct SectionDetail {
    let addressStart: UInt64
    let size: UInt64
    let segament: String
    let section: String
}

typealias Index2ObjDetailMap = [Int: ObjDetail]

class ObjectFilePathFilter {
    private let linkFileInfo: LinkFileAnalyzeInfo
    
    init(linkFileInfo: LinkFileAnalyzeInfo) {
        self.linkFileInfo = linkFileInfo
    }
    
    func filterTagsFrom(_ objectFilePath: String) -> [String] {
        var containedTags = [String]()
        for tag in linkFileInfo.filterPaths {
            if (objectFilePath.contains(tag)) {
                containedTags.append(tag)
            }
        }
        return containedTags
    }
}


class RunningContext {
    let lineSubject: CurrentValueSubject<String, Never>
    var isLineCompleted = false
    
    // result context
    var index2ObjDetailMap = Index2ObjDetailMap()
    var sortedSectionDetail = [SectionDetail]()
    
    init(lineNotifier: CurrentValueSubject<String, Never>) {
        self.lineSubject = lineNotifier
    }
}

class LinkFileParseContext {
    // init context
    let linkFileInfo: LinkFileAnalyzeInfo
    let objectFilePathFilter: ObjectFilePathFilter
    

    var runningContext: RunningContext!
    var isTargetContentParsed: Bool = false
    
    init(linkFileInfo: LinkFileAnalyzeInfo, objectFilePathFilter: ObjectFilePathFilter) {
        self.linkFileInfo = linkFileInfo
        self.objectFilePathFilter = objectFilePathFilter
    }
}
