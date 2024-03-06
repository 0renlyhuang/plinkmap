import Foundation
import Combine

class SectionPhase : WorkPhase<LinkFileParseContext> {
    
    private var subscription: AnyCancellable?
    
    private var parser: SectionParser?
    
    override func onEnter(context: LinkFileParseContext) {
        self.parser = SectionParser(context: context)
        
//        # Sections:
//        # Address    Size        Segment    Section
        
        self.subscription = context.runningContext.lineSubject.dropFirst(2).sink { line in
            self.handleLine(line)
        }
    }
    
    override func onLeave(context: LinkFileParseContext) {
        self.subscription?.cancel()
    }
    
    override func shouldEnter(context: LinkFileParseContext) -> Bool {
        return context.runningContext.lineSubject.value == "# Sections:"
    }
    
    private func handleLine(_ line: String) {
        if (super.shouldEnterNextPhase()) {
            super.enterNextPhase()
            return
        }
        
        self.parser?.handleLine(line)
    }
}
