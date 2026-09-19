import Foundation

/// Programs that draw.
///
/// Interactive Go graphics cannot run here: they want a window, an event loop
/// and a GPU, and WASI has none of those. What runs perfectly is `image` and
/// `image/png` from the standard library — a program that computes pixels and
/// writes a file. The app shows what it drew, so the loop is as tight as
/// printing text, and the result is something worth looking at.
enum GoExampleLibraryGraphics {
    static let all: [GoExample] = [mandelbrot, colourWheel, sineWaves, sierpinski, gameOfLife]

    static let mandelbrot = GoExample(
        id: "graphics.mandelbrot",
        title: "The Mandelbrot set",
        summary: "Escape-time iteration over complex numbers, one pixel at a time.",
        takeaway: "Go has complex128 built in, so the inner loop is the maths and nothing else.",
        conceptTags: [GoConcept.stdlibImage, GoConcept.conversion],
        source: """
        package main

        import (
        \t"fmt"
        \t"image"
        \t"image/color"
        \t"image/png"
        \t"os"
        )

        const (
        \twidth  = 640
        \theight = 480
        \tmaxIter = 120
        )

        // escape returns how many iterations it took for the point to run away,
        // or maxIter if it never did.
        func escape(c complex128) int {
        \tvar z complex128
        \tfor i := 0; i < maxIter; i++ {
        \t\tz = z*z + c
        \t\tif real(z)*real(z)+imag(z)*imag(z) > 4 {
        \t\t\treturn i
        \t\t}
        \t}
        \treturn maxIter
        }

        func shade(iterations int) color.RGBA {
        \tif iterations == maxIter {
        \t\treturn color.RGBA{10, 12, 20, 255}
        \t}
        \tt := float64(iterations) / float64(maxIter)
        \treturn color.RGBA{
        \t\tR: uint8(255 * t),
        \t\tG: uint8(140 * t * t),
        \t\tB: uint8(90 + 120*(1-t)),
        \t\tA: 255,
        \t}
        }

        func main() {
        \tcanvas := image.NewRGBA(image.Rect(0, 0, width, height))
        \tinside := 0

        \tfor py := 0; py < height; py++ {
        \t\ty := float64(py)/height*2.4 - 1.2
        \t\tfor px := 0; px < width; px++ {
        \t\t\tx := float64(px)/width*3.0 - 2.0
        \t\t\tn := escape(complex(x, y))
        \t\t\tif n == maxIter {
        \t\t\t\tinside++
        \t\t\t}
        \t\t\tcanvas.SetRGBA(px, py, shade(n))
        \t\t}
        \t}

        \tfile, err := os.Create("/sandbox/mandelbrot.png")
        \tif err != nil {
        \t\tfmt.Println("could not create the file:", err)
        \t\treturn
        \t}
        \tdefer file.Close()

        \tif err := png.Encode(file, canvas); err != nil {
        \t\tfmt.Println("could not encode the image:", err)
        \t\treturn
        \t}

        \tfmt.Printf("%dx%d, %d pixels in the set\\n", width, height, inside)
        }
        """,
        expectedOutput: "640x480, 65869 pixels in the set\n",
        producesImage: true
    )

    static let colourWheel = GoExample(
        id: "graphics.wheel",
        title: "A colour wheel from scratch",
        summary: "Hue around the circle, saturation towards the rim, written by hand.",
        takeaway: "math.Atan2 gives the angle; the rest is arithmetic on three bytes.",
        conceptTags: [GoConcept.stdlibImage, GoConcept.conversion],
        source: """
        package main

        import (
        \t"fmt"
        \t"image"
        \t"image/color"
        \t"image/png"
        \t"math"
        \t"os"
        )

        const size = 400

        // hsv converts to RGB the long way round, because seeing the six cases
        // written out is the point of the exercise.
        func hsv(h, s, v float64) color.RGBA {
        \tsector := math.Floor(h * 6)
        \tf := h*6 - sector
        \tp := v * (1 - s)
        \tq := v * (1 - f*s)
        \tt := v * (1 - (1-f)*s)

        \tvar r, g, b float64
        \tswitch int(sector) % 6 {
        \tcase 0:
        \t\tr, g, b = v, t, p
        \tcase 1:
        \t\tr, g, b = q, v, p
        \tcase 2:
        \t\tr, g, b = p, v, t
        \tcase 3:
        \t\tr, g, b = p, q, v
        \tcase 4:
        \t\tr, g, b = t, p, v
        \tdefault:
        \t\tr, g, b = v, p, q
        \t}
        \treturn color.RGBA{uint8(r * 255), uint8(g * 255), uint8(b * 255), 255}
        }

        func main() {
        \tcanvas := image.NewRGBA(image.Rect(0, 0, size, size))
        \tradius := float64(size) / 2
        \tpainted := 0

        \tfor y := 0; y < size; y++ {
        \t\tfor x := 0; x < size; x++ {
        \t\t\tdx := float64(x) - radius
        \t\t\tdy := float64(y) - radius
        \t\t\tdistance := math.Hypot(dx, dy)
        \t\t\tif distance > radius {
        \t\t\t\tcanvas.SetRGBA(x, y, color.RGBA{18, 20, 26, 255})
        \t\t\t\tcontinue
        \t\t\t}
        \t\t\t// Atan2 returns -pi..pi; shift it into 0..1 for the hue.
        \t\t\tangle := math.Atan2(dy, dx)
        \t\t\thue := (angle + math.Pi) / (2 * math.Pi)
        \t\t\tcanvas.SetRGBA(x, y, hsv(hue, distance/radius, 1))
        \t\t\tpainted++
        \t\t}
        \t}

        \tfile, err := os.Create("/sandbox/wheel.png")
        \tif err != nil {
        \t\tfmt.Println("could not create the file:", err)
        \t\treturn
        \t}
        \tdefer file.Close()

        \tif err := png.Encode(file, canvas); err != nil {
        \t\tfmt.Println("could not encode the image:", err)
        \t\treturn
        \t}

        \tfmt.Printf("painted %d pixels inside the circle\\n", painted)
        }
        """,
        expectedOutput: "painted 125627 pixels inside the circle\n",
        producesImage: true
    )

    static let sineWaves = GoExample(
        id: "graphics.waves",
        title: "Three waves on one axis",
        summary: "A grid, an axis, and three functions plotted over it.",
        takeaway: "Drawing a curve is choosing a y for every x — there is no plotting library here.",
        conceptTags: [GoConcept.stdlibImage],
        source: """
        package main

        import (
        \t"fmt"
        \t"image"
        \t"image/color"
        \t"image/png"
        \t"math"
        \t"os"
        )

        const (
        \twidth  = 600
        \theight = 300
        )

        type wave struct {
        \tname      string
        \tfrequency float64
        \ttint      color.RGBA
        }

        func main() {
        \tcanvas := image.NewRGBA(image.Rect(0, 0, width, height))

        \t// Background and grid first, so the curves sit on top of them.
        \tfor y := 0; y < height; y++ {
        \t\tfor x := 0; x < width; x++ {
        \t\t\tshade := color.RGBA{16, 18, 24, 255}
        \t\t\tif x%50 == 0 || y%50 == 0 {
        \t\t\t\tshade = color.RGBA{32, 36, 46, 255}
        \t\t\t}
        \t\t\tcanvas.SetRGBA(x, y, shade)
        \t\t}
        \t}
        \tfor x := 0; x < width; x++ {
        \t\tcanvas.SetRGBA(x, height/2, color.RGBA{70, 78, 92, 255})
        \t}

        \twaves := []wave{
        \t\t{"fundamental", 1, color.RGBA{217, 115, 41, 255}},
        \t\t{"third", 3, color.RGBA{90, 190, 140, 255}},
        \t\t{"fifth", 5, color.RGBA{120, 150, 240, 255}},
        \t}

        \tfor _, w := range waves {
        \t\tamplitude := float64(height) / 2.6 / w.frequency
        \t\tfor x := 0; x < width; x++ {
        \t\t\tphase := float64(x) / width * 2 * math.Pi * w.frequency
        \t\t\ty := float64(height)/2 - math.Sin(phase)*amplitude
        \t\t\t// Two pixels thick, so a steep curve does not break up.
        \t\t\tfor _, dy := range []int{0, 1} {
        \t\t\t\trow := int(y) + dy
        \t\t\t\tif row >= 0 && row < height {
        \t\t\t\t\tcanvas.SetRGBA(x, row, w.tint)
        \t\t\t\t}
        \t\t\t}
        \t\t}
        \t\tfmt.Printf("%s: %.1f Hz, amplitude %.0f\\n", w.name, w.frequency, amplitude)
        \t}

        \tfile, err := os.Create("/sandbox/waves.png")
        \tif err != nil {
        \t\tfmt.Println("could not create the file:", err)
        \t\treturn
        \t}
        \tdefer file.Close()

        \tif err := png.Encode(file, canvas); err != nil {
        \t\tfmt.Println("could not encode the image:", err)
        \t}
        }
        """,
        expectedOutput: """
        fundamental: 1.0 Hz, amplitude 115
        third: 3.0 Hz, amplitude 38
        fifth: 5.0 Hz, amplitude 23

        """,
        producesImage: true
    )

    static let sierpinski = GoExample(
        id: "graphics.sierpinski",
        title: "Sierpinski by chaos game",
        summary: "Jump halfway to a random corner, forever. A triangle appears.",
        takeaway: "A deterministic seed makes a random program reproducible — and testable.",
        conceptTags: [GoConcept.stdlibImage],
        source: """
        package main

        import (
        \t"fmt"
        \t"image"
        \t"image/color"
        \t"image/png"
        \t"math/rand"
        \t"os"
        )

        const (
        \tsize   = 500
        \tpoints = 120000
        )

        func main() {
        \tcanvas := image.NewRGBA(image.Rect(0, 0, size, size))
        \tfor y := 0; y < size; y++ {
        \t\tfor x := 0; x < size; x++ {
        \t\t\tcanvas.SetRGBA(x, y, color.RGBA{14, 16, 22, 255})
        \t\t}
        \t}

        \tcorners := [3][2]float64{{size / 2, 10}, {10, size - 10}, {size - 10, size - 10}}

        \t// A fixed seed: the same picture every run, which is what makes this
        \t// an example rather than a surprise.
        \trng := rand.New(rand.NewSource(1))
        \tx, y := float64(size)/2, float64(size)/2
        \tplotted := 0

        \tfor i := 0; i < points; i++ {
        \t\tcorner := corners[rng.Intn(3)]
        \t\tx = (x + corner[0]) / 2
        \t\ty = (y + corner[1]) / 2

        \t\t// The first few points are still wandering in from the middle.
        \t\tif i < 20 {
        \t\t\tcontinue
        \t\t}
        \t\tpx, py := int(x), int(y)
        \t\tif px >= 0 && px < size && py >= 0 && py < size {
        \t\t\tcanvas.SetRGBA(px, py, color.RGBA{230, 150, 60, 255})
        \t\t\tplotted++
        \t\t}
        \t}

        \tfile, err := os.Create("/sandbox/sierpinski.png")
        \tif err != nil {
        \t\tfmt.Println("could not create the file:", err)
        \t\treturn
        \t}
        \tdefer file.Close()

        \tif err := png.Encode(file, canvas); err != nil {
        \t\tfmt.Println("could not encode the image:", err)
        \t\treturn
        \t}

        \tfmt.Printf("plotted %d points\\n", plotted)
        }
        """,
        expectedOutput: "plotted 119980 points\n",
        producesImage: true
    )

    static let gameOfLife = GoExample(
        id: "graphics.life",
        title: "Life, drawn as a filmstrip",
        summary: "Conway's rules for six generations, each one a panel of the image.",
        takeaway: "A 2D grid is a slice of slices, and the rules are four lines of counting.",
        conceptTags: [GoConcept.stdlibImage, GoConcept.sliceAliasing],
        source: """
        package main

        import (
        \t"fmt"
        \t"image"
        \t"image/color"
        \t"image/png"
        \t"os"
        )

        const (
        \tgrid        = 40
        \tcell        = 6
        \tgenerations = 6
        )

        type board [][]bool

        func newBoard() board {
        \tb := make(board, grid)
        \tfor row := range b {
        \t\tb[row] = make([]bool, grid)
        \t}
        \treturn b
        }

        func (b board) neighbours(row, col int) int {
        \tcount := 0
        \tfor dr := -1; dr <= 1; dr++ {
        \t\tfor dc := -1; dc <= 1; dc++ {
        \t\t\tif dr == 0 && dc == 0 {
        \t\t\t\tcontinue
        \t\t\t}
        \t\t\tr, c := row+dr, col+dc
        \t\t\tif r >= 0 && r < grid && c >= 0 && c < grid && b[r][c] {
        \t\t\t\tcount++
        \t\t\t}
        \t\t}
        \t}
        \treturn count
        }

        // step writes into a fresh board: updating in place would let a cell
        // see its neighbour's new state instead of its old one.
        func (b board) step() board {
        \tnext := newBoard()
        \tfor row := 0; row < grid; row++ {
        \t\tfor col := 0; col < grid; col++ {
        \t\t\tn := b.neighbours(row, col)
        \t\t\tnext[row][col] = n == 3 || (b[row][col] && n == 2)
        \t\t}
        \t}
        \treturn next
        }

        func (b board) alive() int {
        \tcount := 0
        \tfor _, row := range b {
        \t\tfor _, cell := range row {
        \t\t\tif cell {
        \t\t\t\tcount++
        \t\t\t}
        \t\t}
        \t}
        \treturn count
        }

        func main() {
        \tb := newBoard()
        \t// An r-pentomino, which stays interesting for a long time.
        \tfor _, seed := range [][2]int{{20, 20}, {20, 21}, {21, 19}, {21, 20}, {22, 20}} {
        \t\tb[seed[0]][seed[1]] = true
        \t}

        \tpanel := grid * cell
        \tcanvas := image.NewRGBA(image.Rect(0, 0, panel*generations, panel))

        \tfor gen := 0; gen < generations; gen++ {
        \t\toffset := gen * panel
        \t\tfor row := 0; row < grid; row++ {
        \t\t\tfor col := 0; col < grid; col++ {
        \t\t\t\tshade := color.RGBA{18, 20, 26, 255}
        \t\t\t\tif b[row][col] {
        \t\t\t\t\tshade = color.RGBA{240, 170, 70, 255}
        \t\t\t\t}
        \t\t\t\tfor y := 0; y < cell; y++ {
        \t\t\t\t\tfor x := 0; x < cell; x++ {
        \t\t\t\t\t\tcanvas.SetRGBA(offset+col*cell+x, row*cell+y, shade)
        \t\t\t\t\t}
        \t\t\t\t}
        \t\t\t}
        \t\t}
        \t\tfmt.Printf("generation %d: %d alive\\n", gen, b.alive())
        \t\tb = b.step()
        \t}

        \tfile, err := os.Create("/sandbox/life.png")
        \tif err != nil {
        \t\tfmt.Println("could not create the file:", err)
        \t\treturn
        \t}
        \tdefer file.Close()

        \tif err := png.Encode(file, canvas); err != nil {
        \t\tfmt.Println("could not encode the image:", err)
        \t}
        }
        """,
        expectedOutput: """
        generation 0: 5 alive
        generation 1: 6 alive
        generation 2: 7 alive
        generation 3: 9 alive
        generation 4: 8 alive
        generation 5: 9 alive

        """,
        producesImage: true
    )
}
