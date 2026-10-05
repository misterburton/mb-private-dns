import Foundation

@main struct ReadinessTests {
    static func main() {
        var state = ResolverReadiness(began: 100)
        func mode(_ now: Double, enabled: Bool = true, error: String = "", conflicts: [String] = [], owner: String = "private-dns") -> String {
            state.mode("attention", enabled: enabled, error: error, conflicts: conflicts, owner: owner, now: now)
        }
        precondition(state.checkDue(now: 100))
        state.record(healthy: false, now: 100)
        precondition(mode(100) == "starting" && mode(129.99) == "starting")
        precondition(!state.checkDue(now: 104.9) && state.checkDue(now: 105))
        precondition(mode(130) == "attention" && mode(200) == "attention")
        precondition(state.checkDue(now: 130), "timeout does not delay recovery checks")
        precondition(mode(105, error: "launch failed") == "attention")
        precondition(mode(105, conflicts: ["Wi-Fi"]) == "attention")
        precondition(state.mode("attention", enabled: true, error: "", conflicts: [], owner: "private-dns", now: 105, routingReady: false) == "attention")
        for owner in ["other", "mixed", "unknown"] { precondition(mode(105, owner: owner) == "attention") }
        precondition(state.mode("paused", enabled: false, error: "", conflicts: [], owner: "private-dns", now: 105) == "paused")
        state.record(healthy: true, now: 110)
        precondition(!state.isStarting(now: 110) && !state.checkDue(now: 139.9) && state.checkDue(now: 140))
        state.record(healthy: false, now: 111)
        precondition(mode(111) == "attention", "a later failure never re-enters startup")
        state = ResolverReadiness(began: 100)
        state.failed = true
        precondition(mode(101) == "attention", "explicit errors or process exits end startup grace")
        print("PASS: startup grace, five-second retry, exact timeout, recovery, steady cadence, pause, routing conflicts, explicit errors and later failures")
    }
}
