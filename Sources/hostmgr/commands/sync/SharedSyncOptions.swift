import ArgumentParser

struct SharedSyncOptions: ParsableArguments {
    @Flag(help: "Force all jobs to run immediately, ignoring the schedule")
    var force: Bool = false
}
