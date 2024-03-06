import Foundation


class WorkPhase<Context> {
    private weak var workFlow: SequentialWorkFlow<Context>!
    
    fileprivate func attach(workFlow: SequentialWorkFlow<Context>) {
        self.workFlow = workFlow
        
    }
    
    func onEnter(context: Context) {
        fatalError("Subclasses must override onEnter")
    }
    
    func onLeave(context: Context) {
        fatalError("Subclasses must override onEnter")
    }
    
    func shouldEnter(context: Context) -> Bool {
        fatalError("Subclasses must override shouldEnter")
    }
    
    func enterNextPhase() {
        self.workFlow.enterNextPhase(self)
    }
    
    func shouldEnterNextPhase() -> Bool {
        return self.workFlow.shouldEnterNextPhase(self)
    }
    
    func getContext() -> Context {
        return self.workFlow.getContext()
    }
}

class ExceptionPhase  {
    func onEnter(msg: String) {
        assert(false, msg)
    }
}
class SequentialWorkFlow<Context> {
    typealias SequentialWorkPhase = WorkPhase<Context>
    
    private let context: Context
    
    private let phases: [SequentialWorkPhase]
    private let exceptionPhase = ExceptionPhase()
    private(set) var isStarted = false
    
    init(phases: [SequentialWorkPhase], context: Context) {
        self.phases = phases
        self.context = context
        
        for phase in phases {
            phase.attach(workFlow: self)
        }
    }
    
    fileprivate func enterNextPhase(_ phase: SequentialWorkPhase) {
        guard let nextPhase = self.getNextPhase(phase) else {
            phase.onLeave(context: self.context)
            return
        }
        
        phase.onLeave(context: self.context)
        nextPhase.onEnter(context: self.context)
    }
    
    fileprivate func shouldEnterNextPhase(_ phase: SequentialWorkPhase) -> Bool {
        guard let nextPhase = self.getNextPhase(phase) else {
            return false
        }
        
        return nextPhase.shouldEnter(context: self.context)
    }
    
    func getContext() -> Context {
        return self.context
    }
    
    private func getNextPhase(_ phase: SequentialWorkPhase) -> SequentialWorkPhase? {
        guard let indexOfThisPhase = self.phases.firstIndex(where: { $0 === phase }) else {
            assert(false, "phase not in phases")
            return nil
        }
        
        if (indexOfThisPhase == self.phases.count - 1) {
            return nil
        }
        
        let nextPhase = self.phases[indexOfThisPhase + 1]
        return nextPhase
    }
    
    func start() {
        guard !self.phases.isEmpty else {
            return
        }
        
        self.isStarted = true
        self.phases[0].onEnter(context: self.context)
    }
}
