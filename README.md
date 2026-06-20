# Swift Concurrency Playground
A playground for Swift Concurrency exploration and exercises.

## What's Inside?
* **Structured Concurrency:** Sequential vs concurrent execution with `async let`.
* **Unstructured Concurrency:** Bridging sync code to async with `Task`.
* **Thread Safety:** `@Sendable` vs `@MainActor` isolation and where each belongs in Clean Architecture.
* **Task Cancellation:** Managing in-flight work with `Task<Void, Never>` and `cancel()`.
* **Independent Error Handling:** Handling partial failures in concurrent operations using separate `do/catch` blocks per `async let` task.
