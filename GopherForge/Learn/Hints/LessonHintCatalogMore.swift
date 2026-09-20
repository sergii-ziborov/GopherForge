import Foundation

extension LessonHintCatalog {
    static var rest: [LessonHint] {
        interfaces + generics + errors + modules + concurrency + stdlib
    }

    static var allAuthored: [String: LessonHint] {
        Dictionary(uniqueKeysWithValues: (Array(authored.values) + rest).map { ($0.lessonID, $0) })
    }

    private static func entry(_ id: String, hint: String, nuance: String) -> LessonHint {
        LessonHint(lessonID: id, hint: hint, nuance: nuance)
    }

    private static let interfaces: [LessonHint] = [
        entry("interfaces.implicit", hint: "Declare the interface next to the function that needs it. One method is enough.", nuance: "Nothing says implements. A type in another package satisfies you without importing you."),
        entry("interfaces.method-sets", hint: "A pointer receiver is only on *T. A T value will not satisfy the interface.", nuance: "Mixing value and pointer receivers on one type is how method-set bugs hide until assignment."),
        entry("interfaces.nil", hint: "Return a bare nil, not a typed nil pointer stored in an interface.", nuance: "An interface is nil only when both type and value are. var p *E; var err error = p is not nil."),
        entry("interfaces.type-switch", hint: "Use value.(type). The one-value assertion panics; the two-value form does not.", nuance: "The comma-ok assertion is the same shape as a map read, on purpose."),
        entry("interfaces.embedding", hint: "Watch which Describe Greet calls. Promotion is not virtual dispatch.", nuance: "The outer method shadows for callers. A promoted sibling still calls the inner one."),
        entry("interfaces.stringer", hint: "fmt.Sprintf the four bytes as a dotted quad. Do not Sprint the value itself.", nuance: "Sprint looks for Stringer. Calling it from String() recurses until the stack blows."),
        entry("interfaces.empty", hint: "return fmt.Sprintf(\"%T\", value). nil is <nil>.", nuance: "any is interface{}. Holding a value throws the static type away; %T is how you peek."),
    ]

    private static let generics: [LessonHint] = [
        entry("generics.type-parameters", hint: "Keep[T any] and filter with the function you are given.", nuance: "T stays the caller's type. any as a parameter would force an assertion on the way out."),
        entry("generics.constraints", hint: "Put ~ on each type in the union so a named Celsius still fits.", nuance: "Without the tilde, only the listed types themselves match. type Celsius float64 would not."),
        entry("generics.containers", hint: "A nil items slice appends fine. Pop returns the zero of T, not nil.", nuance: "var zero T is the zero of whatever T became. T{} is not valid for every type."),
        entry("generics.when-not-to", hint: "If the constraint is one method and you never need the concrete type, take the interface.", nuance: "A type parameter that is only used as an interface is slower to read and the same at runtime."),
        entry("generics.methods", hint: "Map cannot be a method that introduces U. Write it as a function, or keep U off the receiver.", nuance: "Methods repeat the type's parameters. They cannot add new ones. That is why Map is a function in the libraries."),
    ]

    private static let errors: [LessonHint] = [
        entry("errors.wrapping", hint: "fmt.Errorf(\"...: %w\", err). %v formats and loses the cause.", nuance: "errors.Is and errors.As walk %w. They cannot walk a string you built with +."),
        entry("errors.is-and-as", hint: "Type errors.Is(err, sentinel). Do not compare with ==.", nuance: "== fails the moment anyone wraps. Error() strings break when the wording changes."),
        entry("errors.defer", hint: "defer Close right after a successful Open. It runs on every return, including panic.", nuance: "defer is function-scoped, not block-scoped. A defer inside a loop waits until the function ends."),
        entry("errors.custom-type", hint: "Give ParseError an Error() string method. Return a pointer so As can find it.", nuance: "errors.As needs the type you stored. A value and a pointer are different types here too."),
        entry("errors.panic", hint: "Named return err is assigned inside recover. A bare return nil after work() would overwrite it.", nuance: "recover only works in a deferred function. Calling it in the panicked function itself is too late."),
        entry("errors.recover", hint: "defer a function that recover()s and writes the named err. Then call work().", nuance: "Use this at a boundary — one request, one goroutine. It is not a catch block for the whole program."),
    ]

    private static let modules: [LessonHint] = [
        entry("modules.import-path", hint: "The module path plus the directory is the import path. The last element is the package name.", nuance: "internal/ is enforced by the compiler. Only code rooted at its parent may import it."),
        entry("modules.exported-by-case", hint: "A capital letter is the access modifier. There is no export keyword.", nuance: "Parse is visible. parse is not. The rule is the first letter, including on fields and constants."),
        entry("modules.tests", hint: "t.Run each case. Name the cases so -run can select one.", nuance: "A table without t.Run hides every failure after the first. Parallel is t.Parallel, not automatic."),
        entry("modules.naming", hint: "The package name is the last element of the import path, not the folder's marketing name.", nuance: "import \"text/tabwriter\" gives you tabwriter, not text. A stutter (tabwriter.Writer) is the style."),
        entry("modules.init", hint: "init runs before main, once per package. Do not use it for anything a caller should control.", nuance: "init cannot be called. It cannot return an error. A failed init takes down the process."),
    ]

    private static let concurrency: [LessonHint] = [
        entry("concurrency.unbuffered-rendezvous", hint: "A send on make(chan T) waits for a receive. One goroutine cannot do both.", nuance: "The classic deadlock is one line: ch := make(chan int); ch <- 1 in main."),
        entry("concurrency.no-handle", hint: "go f() returns nothing. If you need the result, give f a channel or a WaitGroup.", nuance: "There is no join, no Future. A goroutine you forget is a leak, not a warning."),
        entry("concurrency.channel-close", hint: "The sender closes, once. Range until that close.", nuance: "close is not required for GC. It is a signal. Send after close panics."),
        entry("concurrency.select-context", hint: "select on the value and on ctx.Done(). Return ctx.Err() when the context wins.", nuance: "A function that takes a context and ignores it cannot be cancelled. The first parameter is the convention."),
        entry("concurrency.mutex", hint: "Lock, defer Unlock, then read or write the map. Initialise the map in New.", nuance: "A mutex is for state that stays. A channel is for handing a value over. Do not pick by fashion."),
        entry("concurrency.worker-pool", hint: "Close the input after sending. Range in each worker. Wait, then close the output.", nuance: "Close the output before Wait and a worker panics mid-send. Reverse the order and you deadlock."),
        entry("concurrency.buffered", hint: "make(chan int, n), send 0..n-1, close, range. No extra goroutine.", nuance: "A buffer of n holds n. The n+1st send from the only goroutine deadlocks."),
        entry("concurrency.range-and-close", hint: "for v := range ch. The loop ends when the sender closes.", nuance: "v, ok := <-ch is the same test. ok is false when the channel is closed and empty."),
        entry("concurrency.select-default", hint: "select { case v := <-ch: ... default: return 0, false }.", nuance: "default means try once. A loop of default-selects is a spin, not a wait."),
        entry("concurrency.direction", hint: "Take chan<- int, send, close. A receive in that function should not compile.", nuance: "Bidirectional converts to directional. The other way does not. Close is a send-side operation."),
        entry("concurrency.once", hint: "once.Do(fn). Call it twice in the test; fn must run once.", nuance: "Do is safe for many goroutines. A nil Once panics. Do not copy an Once after first use."),
    ]

    private static let stdlib: [LessonHint] = [
        entry("stdlib.io", hint: "ReadAll the reader, write the uppercased string to the writer.", nuance: "Accept io.Reader and io.Writer, not *os.File. The test passes a buffer on purpose."),
        entry("stdlib.json", hint: "The field tag is the name on the wire. Unmarshal needs a pointer.", nuance: "Without the pointer Unmarshal fills a copy. omitempty skips zeros, including false and 0."),
        entry("stdlib.time", hint: "Duration constants are multiplications. A bare 5 is five nanoseconds.", nuance: "Time comparison uses Before, After, Equal — a Time carries a monotonic reading too."),
        entry("stdlib.sort", hint: "slices.SortFunc with cmp.Compare on year, then name.", nuance: "The comparator returns a number, not a bool. That is the C/Go convention, not JS."),
        entry("stdlib.context", hint: "select on a timer and ctx.Done(). Stop the timer. Return ctx.Err() when cancelled.", nuance: "Sleep cannot be cancelled. A timer plus select can. Never store a context on a struct."),
        entry("stdlib.http", hint: "HandlerFunc. 404 unless the path is /hello, then write hi.", nuance: "httptest is the real types without a listen. Handler is one method: ServeHTTP."),
        entry("stdlib.strconv", hint: "Atoi, then reject n < 1 or n > 65535.", nuance: "Atoi(\"x\") is 0 and an error. Discard the error and you shipped port 0."),
        entry("stdlib.image", hint: "Bounds is image.Rect(0, 0, W, H). At returns C.", nuance: "image.Image is three methods. A PNG file and your Solid both satisfy it."),
    ]
}
