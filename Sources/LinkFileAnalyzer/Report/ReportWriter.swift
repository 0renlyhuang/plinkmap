import Foundation

class ReportWriter {
    private let linkFileInfo: LinkFileAnalyzeInfo
    
    init(_ linkFileInfo: LinkFileAnalyzeInfo) {
        self.linkFileInfo = linkFileInfo
    }
    
    
    func writeHtml(_ index2ObjDetail: Index2ObjDetailMap) async {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                self.writeHtmlImpl(index2ObjDetail)
                continuation.resume()
            }
        }
    }
    
    private func writeHtmlImpl(_ index2ObjDetail: Index2ObjDetailMap) {
        debugLog("doWriteResult")
        
        guard let outputDirUrl = URL(string: self.linkFileInfo.outputDir) else {
            return
        }
        
        let linkFileName = self.linkFileInfo.linkFileName

        let reportFilePath = outputDirUrl.appendingPathComponent("\(linkFileName)_report.html").path
        
        if !FileManager.default.fileExists(atPath: reportFilePath) {
            FileManager.default.createFile(atPath: reportFilePath, contents: nil, attributes: nil)
        }
        
        guard let fileHandle = FileHandle(forWritingAtPath: reportFilePath) else {
            return
        }

        defer {
            fileHandle.closeFile()
        }

        // Truncate the file to remove existing content
        fileHandle.truncateFile(atOffset: 0)

        var sortedObjDetailList = index2ObjDetail.values.sorted { lhs, rhs in
            return lhs.getSize() > rhs.getSize()
        }
        
        for (index, sortedObjDetail) in sortedObjDetailList.enumerated() {
            sortedObjDetailList[index].symbolDetailList = sortedObjDetail.symbolDetailList.sorted { lhs, rhs in
                lhs.symbolSize > rhs.symbolSize
            }
        }

        self.writeHeader(fileHandle)
        
        
        self.writeSummary(fileHandle, index2ObjDetail)
        self.writeObjectFile(fileHandle, sortedObjDetailList)
        self.writeSymbol(fileHandle, sortedObjDetailList)
        self.writeDeadSymbol(fileHandle, sortedObjDetailList)
        
        // Close the HTML document
        let htmlFooterStr = """
        <script src="https://cdn.jsdelivr.net/npm/@popperjs/core@2.9.3/dist/umd/popper.min.js" integrity="sha384-eMNCOe7tC1doHpGoWe/6oMVemdAVTMs2xqW4mwXrXsW0L84Iytr2wi5v2QjrP/xp" crossorigin="anonymous"></script>
            <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.1.0/dist/js/bootstrap.min.js" integrity="sha384-cn7l7gDp0eyniUwwAZgrzD06kc/tftFf19TOAs2zVinnD/C7E91j9yyk5//jjpt/" crossorigin="anonymous"></script>
            <script src="https://cdnjs.cloudflare.com/ajax/libs/jquery-resizable-columns/0.1.0/jquery.resizableColumns.min.js"></script>
        
        </body>
        <style>
            body {
                padding: 20px;
            }
            .card-container {
                padding-bottom: 20px;
            }
            .a-table {
                width: 100%;
                overflow: auto;
            }
            td {
                max-width: 100px;
                overflow: auto;
                word-break: break-all;
            }
          </style>
        </html>
        """
        if let footerData = htmlFooterStr.data(using: .utf8) {
            fileHandle.write(footerData)
        }
        
        debugLog("write html done")
    }
    
    private func writeHeader(_ fileHandle: FileHandle) {
        let headerStr = """
                <!doctype html>
                <html lang="en">
                    <head>
                      <meta charset="utf-8">
                      <meta name="viewport" content="width=device-width, initial-scale=1">
                      <title>Link File Report</title>
                      <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0-alpha1/dist/css/bootstrap.min.css" rel="stylesheet" integrity="sha384-GLhlTQ8iRABdZLl6O3oVMWSktQOp6b7In1Zl3/Jr59b6EGGoI1aFkw7cmDA6j6gD" crossorigin="anonymous">
        
                      <script src="https://code.jquery.com/jquery-3.6.4.min.js"></script>
        
                      <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.7.2/font/bootstrap-icons.css">
                      <link rel="stylesheet" href="https://unpkg.com/bootstrap-table@1.22.2/dist/bootstrap-table.min.css">
                      <script src="https://unpkg.com/bootstrap-table@1.22.2/dist/bootstrap-table.min.js"></script>
        
                      <script src="https://cdn.jsdelivr.net/npm/jquery-resizable-columns@0.2.3/dist/jquery.resizableColumns.min.js"></script>
                      <link href="https://cdn.jsdelivr.net/npm/jquery-resizable-columns@0.2.3/dist/jquery.resizableColumns.min.css" rel="stylesheet">
                    </head>
                <html>
                <body style="margin:20; padding:20">
        """
        
        if let headerData = headerStr.data(using: .utf8) {
            fileHandle.write(headerData)
        }
    }
    
    private func writeSummary(_ fileHandle: FileHandle, _ index2ObjDetail: Index2ObjDetailMap) {
        
        struct SummaryDetail {
            var size: UInt64
            var usingSymbolSize: UInt64
            var deadSymbolSize: UInt64
        }
        
        var tag2Summary = [String: SummaryDetail]()
        self.linkFileInfo.filterPaths.forEach { filterTag in
            tag2Summary[filterTag] = SummaryDetail(size: 0, usingSymbolSize: 0, deadSymbolSize: 0)
        }
        
        for (_, objectDetail) in index2ObjDetail {
            for filterTag in self.linkFileInfo.filterPaths {
                if (objectDetail.userTags.contains(filterTag)) {
                    tag2Summary[filterTag]!.usingSymbolSize += objectDetail.objUsingSymbolSize
                    tag2Summary[filterTag]!.deadSymbolSize += objectDetail.objDeadSymbolSize
                }
            }
        }
        
        
        var summaryTable = """
            <table id="summaryTable" class="table table-bordered a-table">
                <thead class="table-primary">
                    <tr>
                        <th>Tag</th>
                        <th>Using Symbols Size</th>
                        <th>Dead Stripped Symbols Size</th>
                    </tr>
                </thead>
                <tbody>
        """
        
        tag2Summary.forEach { tag, detail in
            summaryTable += """
                <tr>
                    <td>\(tag)</td>
                    <td>\(formatSize(bytes: Int64(detail.usingSymbolSize)))</td>
                    <td>\(formatSize(bytes: Int64(detail.deadSymbolSize)))</td>
                </tr>
            """
        }
        
        summaryTable += """
                </tbody>
            </table>
        """
        
        let summaryCard = self.buildCollapsibleCard(id: "Summary", title: "Summary", bodyHtml: summaryTable, isDefaultExpaned: true)
        
        if let summaryCardData = summaryCard.data(using: .utf8) {
            fileHandle.write(summaryCardData)
        }
    }
    
    
    private func buildCollapsibleCard(id: String, title: String, bodyHtml: String, isDefaultExpaned: Bool) -> String {
//        class="mb-0"
        
        let expanedStr = isDefaultExpaned ? "true" : "false"
        return """
            <div class="accordion card-container" id="\(id)Container">
                <div class="card">
                  <div class="card-header" id="\(id)Header">
                    <h1>
                      <button class="btn btn-link" type="button" data-bs-toggle="collapse" data-bs-target="#\(id)Body" aria-expanded="\(expanedStr)" aria-controls="\(id)Body">
                        \(title)
                      </button>
                    </h1>
                  </div>

                  <div id="\(id)Body" class="collapse \(isDefaultExpaned ? "show" : "")" aria-labelledby="\(id)Header" data-parent="#\(id)Container">
                    <div class="card-body">
                      \(bodyHtml)
                    </div>
                  </div>
                </div>
            </div>
        """
    }
    
    private func writeObjectFile(_ fileHandle: FileHandle, _ sortedObjDetailList: [ObjDetail]) {
        var objectTable = """
            <table id="objectTable" class="table table-bordered table-sm">
                <thead class="table-primary">
                    <tr>
                        <th>Object File</th>
                        <th>Tag</th>
                        <th>All Size</th>
                        <th>Using Symbols Size</th>
                        <th>Dead Stripped Symbols Size</th>
                    </tr>
                </thead>
                <tbody>
        """

        for objDetail in sortedObjDetailList {
            objectTable += """
                <tr>
                    <td>\(objDetail.objectFileName)</td>
                    <td>\(objDetail.userTags.joined(separator: ","))</td>
                    <td>\(formatSize(bytes: Int64(objDetail.getSize())))</td>
                    <td>\(formatSize(bytes: Int64(objDetail.objUsingSymbolSize)))</td>
                    <td>\(formatSize(bytes: Int64(objDetail.objDeadSymbolSize)))</td>
                </tr>
            """
        }

        objectTable += """
                </tbody>
            </table>
        """

        let objectFileCard = self.buildCollapsibleCard(id: "ObjectFile", title: "Object File", bodyHtml: objectTable, isDefaultExpaned: false)
        
        if let objectFileCardData = objectFileCard.data(using: .utf8) {
            fileHandle.write(objectFileCardData)
        }
    }
    
    
    
    private func writeSymbol(_ fileHandle: FileHandle, _ sortedObjDetailList: [ObjDetail]) {
        var symbolTable = """
            <table id="usingSymbolTable" class="table table-bordered table-sm" >
                <thead class="table-primary">
                    <tr>
                        <th>Object File</th>
                        <th>Tag</th>
                        <th>Symbol</th>
                        <th>Size</th>
                        <th>Section</th>
                    </tr>
                </thead>
                <tbody>
        """

        for objDetail in sortedObjDetailList {
            for symbolDetail in objDetail.symbolDetailList {
                if (symbolDetail.isDead) {
                    continue
                }
                
                let sizeStr = formatSize(bytes: Int64(symbolDetail.symbolSize))
                
                var sectionStr = ""
                if let sectionDetail = symbolDetail.sectionDetail {
                    sectionStr = "\(sectionDetail.segament), \(sectionDetail.section)"
                }
                
                symbolTable += """
                    <tr>
                        <td>\(objDetail.objectFileName)</td>
                        <td>\(objDetail.userTags.joined(separator: ","))</td>
                        <td>\(symbolDetail.symbolName)</td>
                        <td>\(sizeStr)</td>
                        <td>\(sectionStr)</td>
                    </tr>
                """
            }
            
        }

        symbolTable += """
                </tbody>
            </table>
        """
        
        
        let symbolCard = self.buildCollapsibleCard(id: "UsingSymbol", title: "Using Symbol", bodyHtml: symbolTable, isDefaultExpaned: false)
        
        if let symbolCardData = symbolCard.data(using: .utf8) {
            fileHandle.write(symbolCardData)
        }
    }
    
    private func writeDeadSymbol(_ fileHandle: FileHandle, _ sortedObjDetailList: [ObjDetail]) {
        var symbolTable = """
            <table id="DeadSymbolTable" class="table table-bordered table-sm" >
                <thead class="table-primary">
                    <tr>
                        <th>Object File</th>
                        <th>Tag</th>
                        <th>Symbol</th>
                        <th>Size</th>
                        <th>Section</th>
                    </tr>
                </thead>
                <tbody>
        """

        for objDetail in sortedObjDetailList {
            for symbolDetail in objDetail.symbolDetailList {
                if (!symbolDetail.isDead) {
                    continue
                }
                
                let sizeStr = formatSize(bytes: Int64(symbolDetail.symbolSize))
                
                var sectionStr = ""
                if let sectionDetail = symbolDetail.sectionDetail {
                    sectionStr = "\(sectionDetail.segament), \(sectionDetail.section)"
                }
                
                symbolTable += """
                    <tr>
                        <td>\(objDetail.objectFileName)</td>
                        <td>\(objDetail.userTags.joined(separator: ","))</td>
                        <td>\(symbolDetail.symbolName)</td>
                        <td>\(sizeStr) (Dead Stripped)</td>
                        <td>\(sectionStr)</td>
                    </tr>
                """
            }
            
        }

        symbolTable += """
                </tbody>
            </table>
        """
        
        
        let symbolCard = self.buildCollapsibleCard(id: "DeadSymbol", title: "Dead Stripped Symbol", bodyHtml: symbolTable, isDefaultExpaned: false)
        
        if let symbolCardData = symbolCard.data(using: .utf8) {
            fileHandle.write(symbolCardData)
        }
    }
}
