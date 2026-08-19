from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "play_store_assets"
RAW = OUT / "raw"
LOGO = ROOT / "assets" / "kukupaja_icon.png"
BACKGROUND = OUT / "feature_background.png"
REFERENCE_BACKGROUND = OUT / "feature_background_reference_style_v2.png"

FONT_REGULAR = Path("C:/Windows/Fonts/segoeui.ttf")
FONT_BOLD = Path("C:/Windows/Fonts/seguisb.ttf")

INK = (7, 7, 8)
CHARCOAL = (27, 22, 22)
RED = (255, 24, 12)
ORANGE = (255, 91, 0)
GOLD = (255, 193, 0)
WHITE = (255, 255, 255)


def font(path: Path, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(path), size)


def cover(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    target_w, target_h = size
    scale = max(target_w / image.width, target_h / image.height)
    resized = image.resize(
        (round(image.width * scale), round(image.height * scale)),
        Image.Resampling.LANCZOS,
    )
    left = (resized.width - target_w) // 2
    top = (resized.height - target_h) // 2
    return resized.crop((left, top, left + target_w, top + target_h))


def fit(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    copy = image.copy()
    copy.thumbnail(size, Image.Resampling.LANCZOS)
    return copy


def rounded(image: Image.Image, radius: int) -> Image.Image:
    mask = Image.new("L", image.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, image.width - 1, image.height - 1),
        radius=radius,
        fill=255,
    )
    result = image.convert("RGBA")
    result.putalpha(mask)
    return result


def make_app_icon() -> None:
    icon = Image.open(LOGO).convert("RGB").resize(
        (512, 512), Image.Resampling.LANCZOS
    )
    icon.save(OUT / "app_icon_512.png", optimize=True)
    icon.convert("RGBA").save(
        OUT / "app_icon_play_store_512_rgba.png",
        optimize=True,
    )


def make_feature_graphic() -> None:
    background = cover(Image.open(BACKGROUND).convert("RGB"), (1024, 500))
    canvas = background.convert("RGBA")

    # Improve copy contrast without hiding the generated ember texture.
    shade = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    shade_draw = ImageDraw.Draw(shade)
    for x in range(1024):
        alpha = max(0, int(145 * (1 - x / 920)))
        shade_draw.line((x, 0, x, 500), fill=(0, 0, 0, alpha))
    canvas = Image.alpha_composite(canvas, shade)

    logo = rounded(
        Image.open(LOGO).convert("RGB").resize(
            (330, 330), Image.Resampling.LANCZOS
        ),
        70,
    )
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    shadow_blob = Image.new("RGBA", (360, 360), (0, 0, 0, 0))
    ImageDraw.Draw(shadow_blob).rounded_rectangle(
        (15, 15, 345, 345), radius=72, fill=(255, 62, 0, 110)
    )
    shadow_blob = shadow_blob.filter(ImageFilter.GaussianBlur(28))
    shadow.alpha_composite(shadow_blob, (27, 70))
    canvas = Image.alpha_composite(canvas, shadow)
    canvas.alpha_composite(logo, (42, 85))

    draw = ImageDraw.Draw(canvas)
    draw.text(
        (414, 142),
        "Kuku bora,",
        font=font(FONT_BOLD, 58),
        fill=WHITE,
        stroke_width=1,
        stroke_fill=(0, 0, 0),
    )
    draw.text(
        (414, 205),
        "bei nzuri.",
        font=font(FONT_BOLD, 58),
        fill=GOLD,
        stroke_width=1,
        stroke_fill=(0, 0, 0),
    )
    draw.text(
        (418, 287),
        "Agiza kuku, mayai na vifaranga kwa urahisi.",
        font=font(FONT_REGULAR, 23),
        fill=(245, 238, 232),
    )

    canvas.convert("RGB").save(
        OUT / "feature_graphic_1024x500.png", optimize=True
    )


def phone_mockup(
    source_name: str,
    width: int,
    height: int,
    angle: float,
) -> Image.Image:
    screenshot = Image.open(RAW / source_name).convert("RGB")
    screenshot = screenshot.crop((0, 92, screenshot.width, screenshot.height))
    screen = cover(screenshot, (width - 22, height - 28))
    screen = rounded(screen, max(18, width // 18))

    phone = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(phone)
    draw.rounded_rectangle(
        (0, 0, width - 1, height - 1),
        radius=max(25, width // 14),
        fill=(8, 8, 9),
        outline=(176, 176, 180),
        width=max(3, width // 70),
    )
    phone.alpha_composite(screen.convert("RGBA"), (11, 14))
    draw.rounded_rectangle(
        (width * 0.37, 8, width * 0.63, 19),
        radius=8,
        fill=(4, 4, 4),
    )
    return phone.rotate(
        angle,
        resample=Image.Resampling.BICUBIC,
        expand=True,
    )


def add_feature_tile(
    canvas: Image.Image,
    x: int,
    y: int,
    label: str,
    code: str,
) -> None:
    draw = ImageDraw.Draw(canvas)
    draw.rounded_rectangle(
        (x, y, x + 112, y + 82),
        radius=16,
        fill=(250, 247, 244, 238),
        outline=(255, 119, 27, 220),
        width=2,
    )
    draw.ellipse((x + 12, y + 12, x + 46, y + 46), fill=(255, 91, 0))
    draw.text(
        (x + 22, y + 15),
        code,
        font=font(FONT_BOLD, 17),
        fill=WHITE,
        anchor="ma",
    )
    draw.text(
        (x + 56, y + 61),
        label,
        font=font(FONT_BOLD, 15),
        fill=(47, 28, 22),
        anchor="mm",
    )


def make_reference_style_feature_graphic() -> None:
    canvas = cover(
        Image.open(REFERENCE_BACKGROUND).convert("RGB"), (1024, 500)
    ).convert("RGBA")

    shade = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    shade_draw = ImageDraw.Draw(shade)
    for x in range(720):
        alpha = max(0, int(72 * (1 - x / 720)))
        shade_draw.line((x, 0, x, 500), fill=(0, 0, 0, alpha))
    canvas = Image.alpha_composite(canvas, shade)

    logo = rounded(
        Image.open(LOGO).convert("RGB").resize((92, 92), Image.Resampling.LANCZOS),
        20,
    )
    canvas.alpha_composite(logo, (34, 28))
    draw = ImageDraw.Draw(canvas)
    draw.text(
        (145, 24),
        "KUKUPAJA",
        font=font(FONT_BOLD, 57),
        fill=WHITE,
    )
    draw.text(
        (35, 123),
        "AGIZA KUKU",
        font=font(FONT_BOLD, 59),
        fill=WHITE,
    )
    draw.text(
        (35, 181),
        "KIGANJANI",
        font=font(FONT_BOLD, 59),
        fill=GOLD,
    )
    draw.text(
        (39, 255),
        "Nunua kuku, mayai na vifaranga",
        font=font(FONT_REGULAR, 24),
        fill=(250, 242, 237),
    )
    draw.text(
        (39, 286),
        "kwa urahisi popote ulipo.",
        font=font(FONT_REGULAR, 24),
        fill=(250, 242, 237),
    )

    add_feature_tile(canvas, 35, 342, "KUKU", "K")
    add_feature_tile(canvas, 158, 342, "MAYAI", "M")
    add_feature_tile(canvas, 281, 342, "VIFARANGA", "V")
    add_feature_tile(canvas, 404, 342, "ODA", "O")

    phone = phone_mockup("01_home.png", 274, 500, 6)
    shadow = Image.new("RGBA", phone.size, (0, 0, 0, 0))
    shadow.alpha_composite(phone)
    shadow = shadow.filter(ImageFilter.GaussianBlur(18))
    canvas.alpha_composite(shadow, (578, 5))
    canvas.alpha_composite(phone, (568, -8))

    canvas.convert("RGB").save(
        OUT / "feature_graphic_reference_style_v2.png",
        optimize=True,
    )


def make_reference_style_screenshot(
    source_name: str,
    output_name: str,
    line_one: str,
    line_two: str,
    subtitle: str,
) -> None:
    canvas = vertical_gradient((1080, 1920)).convert("RGBA")
    draw = ImageDraw.Draw(canvas)

    draw.polygon(
        [(700, 0), (1080, 0), (1080, 710), (810, 540)],
        fill=(174, 23, 8, 150),
    )
    draw.polygon(
        [(845, 0), (1080, 0), (1080, 565), (945, 475)],
        fill=(255, 102, 0, 175),
    )

    logo = rounded(
        Image.open(LOGO).convert("RGB").resize(
            (150, 150), Image.Resampling.LANCZOS
        ),
        32,
    )
    canvas.alpha_composite(logo, (62, 58))
    draw.text(
        (240, 67),
        "KUKUPAJA",
        font=font(FONT_BOLD, 66),
        fill=WHITE,
    )
    draw.text(
        (66, 240),
        line_one,
        font=font(FONT_BOLD, 72),
        fill=WHITE,
    )
    draw.text(
        (66, 320),
        line_two,
        font=font(FONT_BOLD, 72),
        fill=GOLD,
    )
    draw.text(
        (70, 412),
        subtitle,
        font=font(FONT_REGULAR, 34),
        fill=(255, 226, 207),
    )

    add_feature_tile(canvas, 68, 492, "RAHISI", "R")
    add_feature_tile(canvas, 193, 492, "SALAMA", "S")
    add_feature_tile(canvas, 318, 492, "HARAKA", "H")

    phone = phone_mockup(source_name, 760, 1510, 3.2)
    shadow = Image.new("RGBA", phone.size, (0, 0, 0, 0))
    shadow.alpha_composite(phone)
    shadow = shadow.filter(ImageFilter.GaussianBlur(34))
    phone_x = (1080 - phone.width) // 2 + 55
    canvas.alpha_composite(shadow, (phone_x - 18, 585))
    canvas.alpha_composite(phone, (phone_x, 565))
    canvas.convert("RGB").save(OUT / output_name, optimize=True)


def make_reference_style_contact_sheet() -> None:
    names = [
        "phone_v2_01_home_1080x1920.png",
        "phone_v2_02_product_1080x1920.png",
        "phone_v2_03_orders_1080x1920.png",
        "phone_v2_04_account_1080x1920.png",
    ]
    sheet = Image.new("RGB", (940, 600), (17, 17, 18))
    for index, name in enumerate(names):
        image = Image.open(OUT / name).convert("RGB")
        image.thumbnail((215, 430), Image.Resampling.LANCZOS)
        sheet.paste(image, (18 + index * 230, 90))
    ImageDraw.Draw(sheet).text(
        (24, 25),
        "KukuPaja · reference-style screenshots v2",
        font=font(FONT_BOLD, 30),
        fill=WHITE,
    )
    sheet.save(OUT / "screenshots_reference_style_v2_preview.png", optimize=True)


def vertical_gradient(size: tuple[int, int]) -> Image.Image:
    width, height = size
    image = Image.new("RGB", size, INK)
    draw = ImageDraw.Draw(image)
    for y in range(height):
        t = y / max(1, height - 1)
        if t < 0.34:
            q = t / 0.34
            color = tuple(
                round(CHARCOAL[i] * (1 - q) + (46, 12, 7)[i] * q)
                for i in range(3)
            )
        else:
            q = (t - 0.34) / 0.66
            color = tuple(
                round((46, 12, 7)[i] * (1 - q) + INK[i] * q)
                for i in range(3)
            )
        draw.line((0, y, width, y), fill=color)
    return image


def make_store_screenshot(
    source_name: str,
    output_name: str,
    headline: str,
    subtitle: str,
) -> None:
    canvas = vertical_gradient((1080, 1920)).convert("RGBA")
    draw = ImageDraw.Draw(canvas)

    draw.text(
        (70, 45),
        headline,
        font=font(FONT_BOLD, 54),
        fill=WHITE,
    )
    draw.text(
        (72, 116),
        subtitle,
        font=font(FONT_REGULAR, 29),
        fill=(255, 201, 158),
    )
    draw.rounded_rectangle((70, 172, 250, 180), radius=4, fill=ORANGE)
    draw.rounded_rectangle((258, 172, 320, 180), radius=4, fill=GOLD)

    screenshot = Image.open(RAW / source_name).convert("RGB")
    # Remove only the system status bar; keep the app's own navigation intact.
    screenshot = screenshot.crop((0, 100, screenshot.width, screenshot.height))
    screenshot = fit(screenshot, (782, 1640))
    screenshot = rounded(screenshot, 42)

    phone_w = screenshot.width + 26
    phone_h = screenshot.height + 26
    phone_x = (1080 - phone_w) // 2
    phone_y = 214

    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        (phone_x - 13, phone_y - 4, phone_x + phone_w + 13, phone_y + phone_h + 22),
        radius=58,
        fill=(255, 70, 10, 95),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(30))
    canvas = Image.alpha_composite(canvas, shadow)

    draw = ImageDraw.Draw(canvas)
    draw.rounded_rectangle(
        (phone_x, phone_y, phone_x + phone_w, phone_y + phone_h),
        radius=54,
        fill=(10, 10, 11),
        outline=(255, 105, 22),
        width=4,
    )
    canvas.alpha_composite(screenshot, (phone_x + 13, phone_y + 13))
    canvas.convert("RGB").save(OUT / output_name, optimize=True)


def make_contact_sheet() -> None:
    names = [
        "phone_01_home_1080x1920.png",
        "phone_02_product_1080x1920.png",
        "phone_03_orders_1080x1920.png",
        "phone_04_account_1080x1920.png",
    ]
    sheet = Image.new("RGB", (900, 820), (18, 18, 19))
    for index, name in enumerate(names):
        image = Image.open(OUT / name).convert("RGB")
        image.thumbnail((210, 700), Image.Resampling.LANCZOS)
        x = 15 + index * 220
        y = 60
        sheet.paste(image, (x, y))
    ImageDraw.Draw(sheet).text(
        (24, 18),
        "KukuPaja · Google Play assets preview",
        font=font(FONT_BOLD, 27),
        fill=WHITE,
    )
    sheet.save(OUT / "screenshots_preview.png", optimize=True)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    make_app_icon()
    make_feature_graphic()
    make_reference_style_feature_graphic()
    make_store_screenshot(
        "01_home.png",
        "phone_01_home_1080x1920.png",
        "Kuku bora, bei nzuri.",
        "Nunua moja kwa moja kwa urahisi.",
    )
    make_store_screenshot(
        "02_product.png",
        "phone_02_product_1080x1920.png",
        "Chagua unachotaka",
        "Bei, stock na maelezo yote wazi.",
    )
    make_store_screenshot(
        "03_orders.png",
        "phone_03_orders_1080x1920.png",
        "Fuatilia oda zako",
        "Kila hatua, sehemu moja.",
    )
    make_store_screenshot(
        "04_account.png",
        "phone_04_account_1080x1920.png",
        "Huduma zako pamoja",
        "Akaunti, msaada na mipangilio.",
    )
    make_contact_sheet()
    make_reference_style_screenshot(
        "01_home.png",
        "phone_v2_01_home_1080x1920.png",
        "KUKU BORA,",
        "BEI NZURI.",
        "Agiza kwa urahisi popote ulipo.",
    )
    make_reference_style_screenshot(
        "02_product.png",
        "phone_v2_02_product_1080x1920.png",
        "CHAGUA KUKU,",
        "ONA BEI.",
        "Stock na maelezo yote wazi.",
    )
    make_reference_style_screenshot(
        "03_orders.png",
        "phone_v2_03_orders_1080x1920.png",
        "ODA ZAKO,",
        "SEHEMU MOJA.",
        "Fuatilia ununuzi wako kwa urahisi.",
    )
    make_reference_style_screenshot(
        "04_account.png",
        "phone_v2_04_account_1080x1920.png",
        "HUDUMA ZAKO,",
        "PAMOJA.",
        "Akaunti, msaada na mipangilio.",
    )
    make_reference_style_contact_sheet()


if __name__ == "__main__":
    main()
