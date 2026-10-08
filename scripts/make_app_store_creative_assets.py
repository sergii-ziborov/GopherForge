#!/usr/bin/env python3
"""Render App Store header and search artwork from the real editor screenshot."""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
SCREEN = ROOT / "docs/app-store/screenshots/iphone-6.9/00-code.png"
ICON = ROOT / "GopherForge/Resources/Assets.xcassets/AppIcon.appiconset/GopherForgeIcon-1024.png"
OUT = ROOT / "docs/app-store/creative-assets"
AVENIR = "/System/Library/Fonts/Avenir Next.ttc"
MENLO = "/System/Library/Fonts/Menlo.ttc"


def font(size: int, weight: int = 0) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(AVENIR, size, index=weight)


def background(size: tuple[int, int]) -> Image.Image:
    width, height = size
    image = Image.new("RGB", size)
    pixels = image.load()
    for y in range(height):
        for x in range(width):
            glow = max(0, 1 - ((x - width * .74) / (width * .68)) ** 2
                       - ((y - height * .35) / (height * 1.15)) ** 2)
            pixels[x, y] = (
                int(5 + glow * 1),
                int(25 + glow * 34 + y / height * 3),
                int(38 + glow * 43 + y / height * 3),
            )
    draw = ImageDraw.Draw(image)
    for radius in range(420, 2200, 275):
        cx, cy = int(width * .82), int(height * .38)
        draw.ellipse((cx - radius, cy - radius, cx + radius, cy + radius),
                     outline=(15, 75, 93), width=2)
    return image


def rounded_icon(image: Image.Image, x: int, y: int, size: int) -> None:
    source = Image.open(ICON).convert("RGB").resize((size, size), Image.Resampling.LANCZOS)
    mask = Image.new("L", (size, size))
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size - 1, size - 1), radius=size // 5, fill=255)
    image.paste(source, (x, y), mask)


def phone(image: Image.Image, x: int, y: int, width: int) -> None:
    source = Image.open(SCREEN).convert("RGB")
    height = round(source.height * width / source.width)
    screen = source.resize((width, height), Image.Resampling.LANCZOS)
    shadow = Image.new("RGBA", image.size)
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle((x - 30, y - 30, x + width + 30, y + height + 30),
                         radius=112, fill=(0, 0, 0, 170))
    shadow = shadow.filter(ImageFilter.GaussianBlur(55))
    image.paste(shadow, mask=shadow.getchannel("A"))
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle((x - 13, y - 13, x + width + 13, y + height + 13),
                           radius=67, fill=(15, 37, 45), outline=(129, 189, 201), width=3)
    mask = Image.new("L", (width, height))
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, width - 1, height - 1), radius=55, fill=255)
    image.paste(screen, (x, y), mask)


def pill(draw: ImageDraw.ImageDraw, xy: tuple[int, int], label: str) -> None:
    x, y = xy
    label_font = font(49, 5)
    box = draw.textbbox((0, 0), label, font=label_font)
    width = box[2] - box[0] + 76
    draw.rounded_rectangle((x, y, x + width, y + 99), radius=49,
                           fill=(14, 73, 89), outline=(39, 126, 147), width=2)
    draw.text((x + 38, y + 17), label, font=label_font, fill=(199, 242, 248))


def header() -> Image.Image:
    image = background((3840, 1646))
    draw = ImageDraw.Draw(image)
    rounded_icon(image, 245, 170, 152)
    draw.text((435, 199), "GOPHERFORGE", font=font(76, 0), fill=(224, 248, 250))
    draw.rounded_rectangle((245, 442, 362, 460), radius=9, fill=(11, 195, 218))
    draw.text((230, 520), "Real Go.", font=font(181, 0), fill=(248, 252, 252))
    draw.text((230, 736), "On your device.", font=font(160, 0), fill=(248, 252, 252))
    draw.text((245, 1022), "Write, build, test, and learn offline.",
              font=font(77, 5), fill=(179, 223, 232))
    pill(draw, (245, 1235), "Bundled Go toolchain")
    phone(image, 2890, 105, 675)
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle((1970, 1035, 2835, 1460), radius=47,
                           fill=(8, 31, 43), outline=(54, 120, 137), width=3)
    draw.text((2040, 1089), "$ go test ./...", font=ImageFont.truetype(MENLO, 61),
              fill=(139, 227, 238))
    draw.text((2040, 1193), "ok  workerpool", font=ImageFont.truetype(MENLO, 55),
              fill=(228, 247, 246))
    draw.ellipse((2043, 1325, 2087, 1369), fill=(76, 217, 153))
    draw.text((2110, 1300), "Runs locally", font=font(63, 2), fill=(193, 238, 220))
    return image


def search_results() -> Image.Image:
    image = background((2880, 1920))
    draw = ImageDraw.Draw(image)
    rounded_icon(image, 205, 205, 170)
    draw.text((420, 233), "GOPHERFORGE", font=font(76, 0), fill=(224, 248, 250))
    draw.rounded_rectangle((205, 505, 322, 523), radius=9, fill=(11, 195, 218))
    draw.text((192, 600), "Go runs", font=font(183, 0), fill=(248, 252, 252))
    draw.text((192, 822), "right here.", font=font(183, 0), fill=(248, 252, 252))
    draw.text((205, 1137), "Code. Test. Learn.", font=font(83, 5), fill=(179, 223, 232))
    draw.text((205, 1257), "Offline.", font=font(83, 5), fill=(179, 223, 232))
    pill(draw, (205, 1490), "Built on your iPhone")
    phone(image, 1810, 190, 725)
    return image


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for filename, render in (("header.png", header), ("search-results.png", search_results)):
        path = OUT / filename
        render().save(path, format="PNG", optimize=True)
        print(path)


if __name__ == "__main__":
    main()
