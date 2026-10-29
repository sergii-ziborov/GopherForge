# Learning return — stage 2 implementation

This work follows the build 47 source checkpoint; it is not included in that TestFlight binary.

## Implemented contract

- Each editable compile lesson has a versioned local draft, separate from completion history. It is restored before Check, saved after a short typing debounce and flushed on leaving/backgrounding.
- Content identity includes the starter and hidden test. A changed lesson retains the earlier source and explains the change. Reset requires an explicit confirmation and only resets that lesson's draft.
- Inserting an answer preserves the learner's previous source. “Restore my code” does not erase the observed assistance status. Old attempts have unknown assistance; passing compiler evidence remains separate from solution assistance.
- A stale lesson screen cannot replace a newer screen's canonical draft; its source is retained in a separately named recovery document. Draft write failures stay visible.
- Practice is available from the ordinary Course screen and each unit. Predictions, matching, bug hunts, quizzes and Concurrency Lab have visible routes without the old lesson-count gates. Completion callbacks record the same existing progress evidence.
- Guided syntax examples are labelled worked examples, without claiming a typing score.

## Content corrections

Fifty reading prompts had a hint or nuance longer than the existing 240-character usability gate. The short prompt now presents its first complete thought; every original longer explanation is retained in a named reading section. The website export uses the same source. No explanation was discarded merely to pass the length gate.

Three existing hints were corrected against primary documentation:

- [`encoding/json.Unmarshal`](https://pkg.go.dev/encoding/json#Unmarshal): a non-pointer argument returns an InvalidUnmarshalError; it does not silently fill a copy.
- [`strings.Builder`](https://pkg.go.dev/strings#Builder): runtime concatenation can copy growing prefixes; avoid a universal “every + allocates” claim and do not copy a nonzero Builder.
- [Go string types](https://go.dev/ref/spec#String_types): UTF-8 bytes, Unicode code points and user-perceived grapheme clusters are different units.

Failed build/test bundles are retained in `build/audit47/`. The final 34-check model/UI gate passed in `build/audit47/learning-return-final48.xcresult`, including ordinary Practice/Lab navigation and editing, backgrounding, process termination, relaunch and Continue. Earlier UI queries failed because both embedded and full-screen editors shared an identifier; the final test targets the presented editor. A passing first-stage build 47 does not prove these later changes.
