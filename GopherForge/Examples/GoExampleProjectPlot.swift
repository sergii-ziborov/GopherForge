import Foundation

/// Graphics that actually run here.
///
/// Ebiten and Fyne cannot: they need a window and a GPU, and WASI has neither.
/// What runs perfectly is `image` and `image/png` from the standard library —
/// pure Go, no system calls beyond writing a file — so a program draws into a
/// buffer, encodes a PNG into its sandbox, and the app shows what it drew.
///
/// That is the honest shape of graphics in this product, and it is a real one:
/// charts, plots, generated art and image processing are all this.
enum GoExampleProjectPlot {
    static let plot = GoExample(
        id: "project.plot",
        title: "Draw a chart",
        summary: "Render a bar chart to a PNG the app shows beneath the output.",
        takeaway: "image.RGBA is just a byte slice with a stride; PNG is one call away.",
        conceptTags: [GoConcept.sliceCapacity, GoConcept.stdlibIO],
        source: """
        package main

        import (
        \t"fmt"
        \t"image"
        \t"image/color"
        \t"image/png"
        \t"os"

        \t"example.com/plot/internal/chart"
        )

        func main() {
        \tvalues := []float64{3, 7, 4, 9, 6, 2, 8}

        \tcanvas := image.NewRGBA(image.Rect(0, 0, 480, 240))
        \tchart.Fill(canvas, color.RGBA{18, 18, 20, 255})
        \tchart.Bars(canvas, values, color.RGBA{232, 122, 44, 255})

        \t// /sandbox is the one directory a program may write to, and the app
        \t// looks there for images once the program has finished.
        \tfile, err := os.Create("/sandbox/chart.png")
        \tif err != nil {
        \t\tfmt.Println("create:", err)
        \t\treturn
        \t}
        \tdefer file.Close()

        \tif err := png.Encode(file, canvas); err != nil {
        \t\tfmt.Println("encode:", err)
        \t\treturn
        \t}
        \tfmt.Printf("drew %d bars into %dx%d\\n", len(values), canvas.Bounds().Dx(), canvas.Bounds().Dy())
        }
        """,
        expectedOutput: "drew 7 bars into 480x240\n",
        extraFiles: [
            "internal/chart/chart.go": """
            // Package chart draws onto an image. No windows, no GPU: every pixel
            // here is a byte in a slice.
            package chart

            import (
            \t"image"
            \t"image/color"
            )

            // Fill paints the whole image one colour.
            func Fill(canvas *image.RGBA, shade color.RGBA) {
            \tbounds := canvas.Bounds()
            \tfor y := bounds.Min.Y; y < bounds.Max.Y; y++ {
            \t\tfor x := bounds.Min.X; x < bounds.Max.X; x++ {
            \t\t\tcanvas.SetRGBA(x, y, shade)
            \t\t}
            \t}
            }

            // Bars draws one bar per value, scaled to the tallest.
            func Bars(canvas *image.RGBA, values []float64, shade color.RGBA) {
            \tif len(values) == 0 {
            \t\treturn
            \t}
            \tbounds := canvas.Bounds()
            \tpadding := 12
            \tmax := values[0]
            \tfor _, v := range values {
            \t\tif v > max {
            \t\t\tmax = v
            \t\t}
            \t}
            \tif max <= 0 {
            \t\treturn
            \t}

            \tusable := bounds.Dx() - padding*2
            \tslot := usable / len(values)
            \twidth := slot - 6
            \tfor index, value := range values {
            \t\theight := int(float64(bounds.Dy()-padding*2) * value / max)
            \t\tleft := padding + index*slot
            \t\ttop := bounds.Max.Y - padding - height
            \t\tfor y := top; y < bounds.Max.Y-padding; y++ {
            \t\t\tfor x := left; x < left+width; x++ {
            \t\t\t\tcanvas.SetRGBA(x, y, shade)
            \t\t\t}
            \t\t}
            \t}
            }
            """,
            "internal/chart/chart_test.go": """
            package chart

            import (
            \t"image"
            \t"image/color"
            \t"testing"
            )

            func TestBarsDrawSomething(t *testing.T) {
            \tcanvas := image.NewRGBA(image.Rect(0, 0, 100, 100))
            \tBars(canvas, []float64{1}, color.RGBA{255, 0, 0, 255})

            \tif canvas.RGBAAt(50, 95).R != 255 {
            \t\tt.Error("expected the bar to reach the bottom of the canvas")
            \t}
            }

            func TestBarsSurviveNoValues(t *testing.T) {
            \tcanvas := image.NewRGBA(image.Rect(0, 0, 10, 10))
            \tBars(canvas, nil, color.RGBA{})
            }
            """,
        ],
        modulePath: "example.com/plot",
        producesImage: true
    )
}
