import ArgumentParser

struct CLIArguments: ParsableArguments {
  @Option(help: "Use debug mode?")
  var debug: Bool = false
}
