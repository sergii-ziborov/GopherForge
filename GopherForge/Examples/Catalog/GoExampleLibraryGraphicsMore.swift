import Foundation

/// More pictures: a colour field and a clock face, still just pixels and PNG.
enum GoExampleLibraryGraphicsMore {
    static let all: [GoExample] = [plasma, clock]

    static let plasma = GoExample(
        id: "graphics.plasma",
        title: "A plasma field",
        summary: "Sines stacked on sines, mapped onto a colour wheel.",
        takeaway: "A pretty picture is still a nested loop and a palette.",
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
        \twidth  = 320
        \theight = 200
        )

        func main() {
        \tcanvas := image.NewRGBA(image.Rect(0, 0, width, height))
        \tfor y := 0; y < height; y++ {
        \t\tfor x := 0; x < width; x++ {
        \t\t\tfx := float64(x) / width
        \t\t\tfy := float64(y) / height
        \t\t\tv := math.Sin(fx*12) + math.Sin(fy*9) + math.Sin((fx+fy)*8)
        \t\t\thue := (v + 3) / 6
        \t\t\tcanvas.SetRGBA(x, y, color.RGBA{
        \t\t\t\tR: uint8(40 + 200*hue),
        \t\t\t\tG: uint8(30 + 120*(1-hue)),
        \t\t\t\tB: uint8(90 + 140*math.Abs(math.Sin(hue*math.Pi))),
        \t\t\t\tA: 255,
        \t\t\t})
        \t\t}
        \t}

        \tfile, err := os.Create("/sandbox/plasma.png")
        \tif err != nil {
        \t\tfmt.Println("could not create the file:", err)
        \t\treturn
        \t}
        \tdefer file.Close()
        \tif err := png.Encode(file, canvas); err != nil {
        \t\tfmt.Println("could not encode the image:", err)
        \t\treturn
        \t}
        \tfmt.Printf("%dx%d plasma\\n", width, height)
        }
        """,
        expectedOutput: "320x200 plasma\n",
        producesImage: true
    )

    static let clock = GoExample(
        id: "graphics.clock",
        title: "A clock that never ticks",
        summary: "Hands at 15:04, drawn with sines rather than a widget.",
        takeaway: "Fifteen-oh-four is the time Go uses in its own layouts — here it is a picture.",
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
        \tsize = 240
        \thour = 15
        \tmin  = 4
        )

        func main() {
        \tcanvas := image.NewRGBA(image.Rect(0, 0, size, size))
        \tcx, cy := float64(size)/2, float64(size)/2
        \tradius := float64(size)/2 - 12

        \tfor y := 0; y < size; y++ {
        \t\tfor x := 0; x < size; x++ {
        \t\t\tdx := float64(x) - cx
        \t\t\tdy := float64(y) - cy
        \t\t\td := math.Hypot(dx, dy)
        \t\t\tif d < radius {
        \t\t\t\tcanvas.SetRGBA(x, y, color.RGBA{245, 239, 226, 255})
        \t\t\t} else if d < radius+6 {
        \t\t\t\tcanvas.SetRGBA(x, y, color.RGBA{40, 44, 52, 255})
        \t\t\t} else {
        \t\t\t\tcanvas.SetRGBA(x, y, color.RGBA{24, 26, 32, 255})
        \t\t\t}
        \t\t}
        \t}

        \tstroke(canvas, cx, cy, hourHand(hour, min), radius*0.55, color.RGBA{40, 44, 52, 255})
        \tstroke(canvas, cx, cy, minuteHand(min), radius*0.78, color.RGBA{196, 92, 38, 255})

        \tfile, err := os.Create("/sandbox/clock.png")
        \tif err != nil {
        \t\tfmt.Println("could not create the file:", err)
        \t\treturn
        \t}
        \tdefer file.Close()
        \tif err := png.Encode(file, canvas); err != nil {
        \t\tfmt.Println("could not encode the image:", err)
        \t\treturn
        \t}
        \tfmt.Printf("%d:%02d clock\\n", hour, min)
        }

        func hourHand(h, m int) float64 {
        \treturn (float64(h%12) + float64(m)/60) / 12 * 2 * math.Pi
        }

        func minuteHand(m int) float64 {
        \treturn float64(m) / 60 * 2 * math.Pi
        }

        func stroke(canvas *image.RGBA, cx, cy, angle, length float64, tint color.RGBA) {
        \t// 12 o'clock is up, so subtract π/2 from the usual unit-circle angle.
        \tangle -= math.Pi / 2
        \tsteps := int(length)
        \tfor i := 0; i < steps; i++ {
        \t\tt := float64(i) / length
        \t\tx := int(cx + math.Cos(angle)*length*t)
        \t\ty := int(cy + math.Sin(angle)*length*t)
        \t\tif x >= 0 && y >= 0 && x < size && y < size {
        \t\t\tcanvas.SetRGBA(x, y, tint)
        \t\t}
        \t}
        }
        """,
        expectedOutput: "15:04 clock\n",
        producesImage: true
    )
}
