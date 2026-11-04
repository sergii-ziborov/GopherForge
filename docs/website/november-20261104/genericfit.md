## Start with the duplication you can explain

A team has three small helpers that turn identifiers into labels. Someone proposes replacing them with a generic repository, a generic service and a generic response pipeline. The pull request removes repeated loops but introduces type parameters throughout unrelated business logic. Another engineer rejects all generics because ordinary functions used to work. Both positions skip the useful question: what invariant is actually shared, and which differences should remain visible to callers?

This guide belongs to the **30 October 2026 archive edition** and was first researched and published on **4 November 2026**. It uses original examples tested with Go 1.27.3, including the generic-method syntax introduced in Go 1.27. The purpose is to make API choices concrete. There is no universal ranking in which generics defeat interfaces or interfaces defeat direct functions. The better design exposes the contract with the least unnecessary machinery.

Begin by collecting two real call sites and one likely change. If the shared operation is simply a loop that preserves element relationships, a generic helper may be useful. If callers need different external behaviors, an interface may express the boundary. If the only benefit is avoiding six obvious lines, a direct function may be the easiest code to maintain.

## Keep ordinary functions in the comparison

Suppose one endpoint converts internal order identifiers into a public response. The conversion includes an authorization decision, localization and a missing-record policy. These operations are not interchangeable just because another endpoint also iterates over a slice. An explicit `OrderLabels` function can keep the decisions together and give the operation a meaningful name. A reusable loop should not hide the rules that determine what a customer is allowed to see.

Write the direct version first. Identify its inputs, output ownership, error behavior and order guarantees. Then ask which parts remain identical when a second input type appears. This produces a much better generic candidate than designing a type hierarchy before any useful operation exists. It also gives reviewers a baseline against which to assess the abstraction's actual cost.

One practical review technique is to read only the call sites. Can a colleague infer the result type and the failure policy without opening several helper packages? If not, the abstraction may be moving complexity rather than removing it. This does not imply that a longer function is always clearer. It means that local brevity and system-wide comprehensibility are different measurements, and both deserve attention before publishing a reusable API.

## Choose a contract before choosing a mechanism

Use four questions: what relationship must remain true, which concrete types vary, which behavior varies, and what experiment could disprove the design? A typed collection transformation relates input elements to output elements. A storage adapter varies behavior behind a small set of operations. A domain command may need neither mechanism because its business meaning is already specific.

Consider a slice mapping operation. Its contract might preserve order and nil input, allocate independent outer result storage and call the supplied function once for each element. Those promises can be expressed and tested without mentioning a database, HTTP server or architecture pattern. That makes the operation a reasonable generic candidate. The business-specific conversion can remain an ordinary function passed to it.

Now consider a receipt writer. The caller needs a `WriteReceipt` behavior from either a local file adapter or a remote service adapter. An interface near that caller can express the required operation. Making the entire application generic over every adapter type may increase coupling without adding useful guarantees. The [Go generics tutorial](https://go.dev/doc/tutorial/generics) provides the language starting point; the decision framework here is a review method built around concrete callers and explicit tests.

## Constraints describe permitted operations, not business truth

A constraint restricts a type parameter's possible arguments. It does not certify that every value of those types satisfies the application invariant. An integer constraint does not establish that an account quantity is positive. A string-like constraint does not establish valid UTF-8, a permitted identifier alphabet or an authorized resource name. Those remain value-level checks at an appropriate boundary.

The [language specification](https://go.dev/ref/spec#Type_constraints) explains type sets and underlying-type terms. In the lab, `S ~[]E` allows a named slice type while retaining its element relationship. This is useful when callers define domain-specific slice names. It is not a reason to accept every representation into every helper. A narrower signature may communicate more than an elaborate union that admits values the implementation cannot sensibly interpret.

Design constraints from operations the implementation actually uses. If a helper only needs equality, do not require ordering. If ordering has domain-specific rules, accept an explicit comparison function rather than pretending numeric order answers the question. Names should also reflect the promise: a helper called `Normalize` is much harder to assess than one called `SortByPriority`. The constraint and the function name work together; neither can substitute for an explanation of the domain policy.

## Interfaces describe behavior at a useful boundary

An interface is valuable when the caller needs an operation while the implementation can vary. Keep it near the consumer and as small as the actual requirement permits. A reader that only needs to retrieve one configuration value should not depend on a giant administration interface merely because an existing concrete client implements it. The large interface would make every test and alternative adapter carry unrelated obligations.

Generic functions and behavioral interfaces can coexist. A generic collection helper can accept an ordinary function that invokes a small interface. A concrete service can expose a stable non-generic interface while using typed helpers internally. The architectural choice is not a binary switch applied to an entire repository. Different boundaries can use different mechanisms because they solve different kinds of variation.

Pay particular attention to test doubles. If a fake must reproduce a large external SDK, the production boundary may be too broad. If a fake ignores deadlines or collapses a miss and an outage into one result, the tests may be protecting the wrong contract. Our [architecture introduction](/blog/choose-a-go-architecture) and [error-contract article](/news/go-typed-nil-errors-as-contracts) provide useful companion exercises. A small interface is helpful because its semantics can be stated clearly, not merely because it contains fewer method declarations.

## Generic methods expand organization without changing every interface

Go 1.27 permits a concrete method to declare its own type parameters. The [official generic-methods explanation](https://go.dev/blog/generic-methods) also identifies an important boundary: interface methods cannot declare their own type parameters, and a generic method does not become an implementation of an ordinary interface method merely because one instantiation appears to have the desired signature.

Our small example uses a generic method to organize a transformation beside the container it transforms:

```go
type Box[T any] struct {
    Value T
}

func (b Box[T]) Map[U any](fn func(T) U) Box[U] {
    return Box[U]{Value: fn(b.Value)}
}
```

The test transforms an integer box into a string box using `strconv.Itoa`. It verifies a useful type relationship without introducing a runtime registry or reflection. The method still says nothing about cancellation, ownership of referenced objects or whether a supplied function can fail. Those would need additional contract decisions rather than an assumption that type parameters automatically provide them.

When supporting an older compiler, offer an ordinary generic function with an equivalent relationship or keep the older API until the module can raise its language requirement. Do not publish syntax that requires a newer toolchain while claiming that only an editor upgrade is necessary.

## Nil preservation and copying deserve explicit tests

The lab's `MapSlice` returns nil for nil input and otherwise allocates a new outer slice. These are deliberate API choices. Another library could reasonably choose a non-nil empty result, but switching between the two can affect consumers that distinguish absent data from an empty collection. The contract should be selected before a refactor rather than discovered through a downstream serialization difference.

Independent outer storage also does not imply a deep copy. If the mapping function returns a pointer, map or slice from the input, the referenced object may remain shared. One of our tests changes a pointed-to integer through the output and observes the original value change. That test documents the intended limit instead of advertising independence that the function never promised.

Think through ownership with a concrete caller. If the result is retained in a cache while the input buffer becomes reusable, sharing may be wrong. If both views intentionally observe the same immutable object, copying every nested structure may be wasteful. The [slice backing-array guide](/news/go-slices-backing-array-append-clip-clone) develops this distinction. Type parameters preserve type relationships; they do not decide lifetime or mutability policies. These concerns should remain visible in the helper's documentation and in tests that change one side after construction.

## Comparable does not make every key well behaved

The `comparable` constraint permits equality operations and map-key use for applicable types. It does not guarantee that every value compares equal to itself or that an interface key cannot contain an unsuitable dynamic value. Floating-point NaN is a particularly instructive fixture. The lab inserts a NaN key into a map, observes a length of one and then fails to retrieve that entry using the same NaN variable.

This is not a defect in generic syntax. It is a mismatch between a permitted operation and the stronger mathematical behavior an algorithm assumed. A set abstraction that accepts floating-point keys needs to decide how NaNs should be treated. An interface-keyed cache needs to control the values its callers can supply. Neither question disappears when the compiler accepts the declaration.

The [cmp package](https://pkg.go.dev/cmp) documents its ordering and NaN behavior. Choose that behavior deliberately if it matches the algorithm, or define a domain-specific rule. An especially useful interview follow-up is to ask whether a generic deduplication helper should preserve the first representation of a value, canonicalize it or reject unsupported cases. A correct answer discusses the contract before proposing an implementation, and tests a value that violates the simplest assumption.

## Public APIs create a longer obligation than local helpers

An internal helper can be changed alongside its callers. An exported generic API becomes a commitment to callers you may never see. The chosen type parameters, inference behavior, constraints and nil semantics all affect future changes. A constraint that seems convenient today can be difficult to tighten later without breaking users. A highly general name can also invite uses outside the cases you actually tested.

Before exporting, write several examples that a new user could compile without reading the implementation. Include named types, empty input and one rejected design alternative. Explain which compiler version the syntax requires. Avoid encoding every possible future use into the first release. A smaller supported surface is often easier to improve because its behavior can be demonstrated rather than guessed.

The module's Go directive and the selected toolchain should be part of the reproducibility record. Our [toolchain and artifact article](/news/go-reproducible-build-report-october-21-2026) is relevant here: a developer machine accepting a feature is not proof that every supported build environment accepts it. Review CI, local tooling and teaching environments before raising the minimum. Version compatibility is a user-facing property of a library, not an administrative detail to fix after publication.

## Test semantics before making performance claims

The supplied package tests a cross-type generic method, a named slice input, nil preservation, independent outer storage, shared nested references and the NaN counterexample. These are different assertions because they protect different promises. Combining them into a single happy-path example would make a future failure harder to interpret and might hide which behavior a refactor changed.

Do not infer performance from syntax alone. A generic implementation, an interface-based implementation and a direct loop can differ according to inlining, representation, workload and compiler version. Compare equivalent behavior under the selected compiler if performance matters. Include allocation and retention effects, not just a short elapsed-time number. The [profiling lab](/news/go-allocation-profiling-pprof-escape-benchmarks) explains how to keep those measurements separate.

A useful experiment starts with a real repeated operation, preserves its output and error contract, and changes one implementation choice. An unrepresentative microbenchmark can favor an abstraction that complicates the actual program. This article supplies correctness fixtures rather than invented speedups. A faster result is meaningful only when it still performs the same work and remains understandable enough for the next engineer to maintain.

## Practice the decision in a small workspace

[Download the six-topic Go lab](/downloads/go-engineering-lab-20261104.zip) and run `go test ./genericlab` with a compatible Go 1.27 compiler. The full module records its dependencies and compiler requirement. The generic package itself uses only the standard library, and its examples do not require a database or network service. Keep the supplied tests when adapting the code so that changes to ownership or nil semantics remain observable.

For a personal exercise, start with two concrete functions that genuinely share an invariant. Write a generic version and compare the call sites. Then attempt the same refactor on two operations that merely look similar. Explain why sharing the loop may be harmless while sharing the business operation would be misleading. This contrast is much more educational than converting every function in a project into a generic one.

The [generics lessons](/learn/generics.type-parameters), [generic-method lesson](/learn/generics.methods) and [when-not-to lesson](/learn/generics.when-not-to) provide a guided route. You can also use [Playground](/playground) for a compatible example after saving your current draft. An AI assistant can propose alternatives through the [MCP workflow](/guide/mcp), but you still need to inspect the actual compiler requirement and tests before accepting its abstraction.

## A review that ends with a concrete choice

Ask the author to state the shared invariant in one sentence. Ask which differences are intentionally left outside the helper. Check the ownership and error policy, then examine a named type, empty input and one awkward value. If the explanation depends primarily on a claim that a feature is modern, return to the direct implementation and compare again.

For a library, include a migration example and a minimum-toolchain statement. For an application, keep the abstraction close to the callers until its meaning stabilizes. For interview preparation, explain why a small interface can be a better boundary than a generic service, while a generic container transformation can be clearer than repeated type-specific helpers. The purpose is to reason about variation rather than defend a preferred language feature.

Finish by recording the choice and the evidence that supports it. A short comment describing a non-obvious nil policy or a test demonstrating shared nested references is often more valuable than another layer of type machinery. The resulting API should make useful programs easier to write and incorrect assumptions easier to notice. That is a practical standard a reviewer can apply to generics, interfaces and ordinary functions alike.
