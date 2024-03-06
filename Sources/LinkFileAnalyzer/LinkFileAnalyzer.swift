import Foundation

class LinkFileAnalyzer {
    private let linkFileInfo: LinkFileAnalyzeInfo
    
    init(_ linkFileInfo: LinkFileAnalyzeInfo) {
        self.linkFileInfo = linkFileInfo
    }
    
    func analyze() async {
        let reader = FileReader(self.linkFileInfo)
        let parser = LinkFileParser(self.linkFileInfo, onTargetContentParsed: {
            reader.stopRead()
        })
        
        await reader.read() { lines in
            parser.parse(lines)
        }
        
        let index2ObjDetailMap = await parser.waitParseResult();
        
        let reportWriter = ReportWriter(self.linkFileInfo)
        await reportWriter.writeHtml(index2ObjDetailMap)
    }
}
