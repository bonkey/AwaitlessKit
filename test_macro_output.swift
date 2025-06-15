import AwaitlessKit

@CompletionBlock
func greet(name: String, loudly: Bool = false) async -> String {
    await Task.sleep(nanoseconds: 1_000_000)
    return loudly ? "HELLO, \(name.uppercased())!" : "Hello, \(name)."
}

