
import Foundation
import ArgumentParser

@main
struct PlinkmapCLI : AsyncParsableCommand {
    static var configuration = CommandConfiguration(abstract: "This is a linkMap file parse tool. Provide linkmap-paths output-dir filters to start")
    
    @Option(name: .shortAndLong, help: "The linkmap files to parse.")
    var linkmapPaths: [String]
    
    @Option(name: .shortAndLong, help: "The output directory.")
    var outputDir: String
    
    @Option(name: .shortAndLong, help: "The tags to filter path of object files.")
    var filters: [String]

    
    mutating func run() async throws {
        debugLog("main")
        
        let analyzerList = linkmapPaths.map { path -> LinkFileAnalyzer? in
            guard let linkFileUrl = URL(string: path) else {
                return nil
            }

            let name = linkFileUrl.deletingPathExtension().lastPathComponent
            
            let linkFileInfo = LinkFileAnalyzeInfo(linkFileName: name, linkFilePath: path, outputDir: outputDir, filterPaths: filters)
            return LinkFileAnalyzer(linkFileInfo)
            
        }.filter { $0 != nil }.map { $0! }
        
        
        await withTaskGroup(of: Void.self) { taskGroup in
            for analyzer in analyzerList {
                taskGroup.addTask {
                    await analyzer.analyze()
                }
            }
        }
        
        debugLog("done")
  }
}
