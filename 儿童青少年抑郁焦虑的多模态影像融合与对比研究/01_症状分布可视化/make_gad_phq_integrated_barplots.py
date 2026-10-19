from pathlib import Path
import xml.etree.ElementTree as ET

from PIL import Image, ImageDraw, ImageFont


OUT_DIR = Path(__file__).resolve().parent / "outputs"
OUT_DIR.mkdir(exist_ok=True)

W, H = 3000, 2050
WHITE = "#FFFFFF"
TEXT = "#202124"
MUTED = "#5F6368"
GRID = "#D9DEE5"
BLUE = "#5F89B1"
RED = "#D89090"
NOTE_BG = "#F5F7FA"
FONT_PATH = "/System/Library/Fonts/STHeiti Medium.ttc"
FONT_FAMILY = "STHeiti, 'PingFang SC', 'Microsoft YaHei', Arial, sans-serif"

CATEGORIES = [
    ("0–4", "无或极轻微"),
    ("5–9", "轻度"),
    ("10–14", "中度"),
    ("≥15", "高症状水平"),
]

PANELS = [
    {
        "title": "A  所有量表被试",
        "subtitle": "GAD-7 n = 5,343；PHQ-9 n = 5,363",
        "gad": [3212, 1477, 506, 148],
        "phq": [2922, 1522, 603, 316],
        "ymax": 3500,
        "step": 500,
    },
    {
        "title": "B  三模态数据匹配后",
        "subtitle": "GAD-7 n = 3,063；PHQ-9 n = 3,074",
        "gad": [1847, 854, 277, 85],
        "phq": [1680, 875, 346, 173],
        "ymax": 2000,
        "step": 500,
    },
]


image = Image.new("RGB", (W, H), WHITE)
canvas = ImageDraw.Draw(image)
font_cache = {}

ET.register_namespace("", "http://www.w3.org/2000/svg")
svg = ET.Element("svg", {
    "xmlns": "http://www.w3.org/2000/svg",
    "width": str(W), "height": str(H), "viewBox": f"0 0 {W} {H}",
    "role": "img", "aria-labelledby": "title desc",
})
ET.SubElement(svg, "title", {"id": "title"}).text = "整合后的GAD-7与PHQ-9症状分层柱状图"
ET.SubElement(svg, "desc", {"id": "desc"}).text = (
    "上下两个整合柱状图，蓝色为GAD-7，红色为PHQ-9。"
    "四个共同分数段均采用成对柱，其中大于等于15分为合并后的高症状水平。"
)
ET.SubElement(svg, "rect", {
    "x": "0", "y": "0", "width": str(W), "height": str(H), "fill": WHITE,
})


def get_font(size):
    if size not in font_cache:
        font_cache[size] = ImageFont.truetype(FONT_PATH, size=size)
    return font_cache[size]


def draw_text(x, y, value, size, fill=TEXT, anchor="middle", weight="400"):
    pil_anchor = {"middle": "mm", "start": "lm", "end": "rm"}[anchor]
    canvas.text((x, y), value, font=get_font(size), fill=fill, anchor=pil_anchor)
    ET.SubElement(svg, "text", {
        "x": f"{x:.1f}", "y": f"{y:.1f}", "fill": fill,
        "font-family": FONT_FAMILY, "font-size": str(size),
        "font-weight": weight, "text-anchor": anchor,
        "dominant-baseline": "middle",
    }).text = value


def draw_line(x1, y1, x2, y2, fill, width=2, dash=None):
    if dash:
        position = y1
        while position < y2:
            canvas.line((x1, position, x2, min(position + dash[0], y2)),
                        fill=fill, width=width)
            position += sum(dash)
    else:
        canvas.line((x1, y1, x2, y2), fill=fill, width=width)
    attrs = {
        "x1": f"{x1:.1f}", "y1": f"{y1:.1f}",
        "x2": f"{x2:.1f}", "y2": f"{y2:.1f}",
        "stroke": fill, "stroke-width": str(width),
    }
    if dash:
        attrs["stroke-dasharray"] = f"{dash[0]} {dash[1]}"
    ET.SubElement(svg, "line", attrs)


def draw_rect(x, y, width, height, fill, radius=0):
    canvas.rounded_rectangle((x, y, x + width, y + height),
                             radius=radius, fill=fill)
    ET.SubElement(svg, "rect", {
        "x": f"{x:.1f}", "y": f"{y:.1f}",
        "width": f"{width:.1f}", "height": f"{height:.1f}",
        "fill": fill, "rx": str(radius),
    })


def draw_multiline(x, y, lines, size, gap, fill=TEXT):
    for index, value in enumerate(lines):
        draw_text(x, y + index * gap, value, size, fill=fill)


def draw_panel(panel, top, bottom):
    left, right = 150, 2870
    draw_text(left, top, panel["title"], 45, anchor="start", weight="500")
    draw_text(right, top, panel["subtitle"], 30, fill=MUTED, anchor="end")

    plot_left = left + 105
    plot_right = right
    plot_top = top + 90
    plot_bottom = bottom - 120
    plot_width = plot_right - plot_left
    plot_height = plot_bottom - plot_top

    draw_text(plot_left, plot_top - 30, "被试人数（n）", 28,
              fill=MUTED, anchor="start")
    tick = 0
    while tick <= panel["ymax"]:
        yy = plot_bottom - tick / panel["ymax"] * plot_height
        draw_line(plot_left, yy, plot_right, yy, GRID, 2)
        draw_text(plot_left - 20, yy, f"{tick:,}", 28,
                  fill=MUTED, anchor="end")
        tick += panel["step"]
    draw_line(plot_left, plot_top, plot_left, plot_bottom, TEXT, 3)
    draw_line(plot_left, plot_bottom, plot_right, plot_bottom, TEXT, 3)

    slot = plot_width / len(CATEGORIES)
    bar_width = min(115, slot * 0.30)
    pair_gap = 10

    for index, ((score, severity), gad_value, phq_value) in enumerate(zip(
            CATEGORIES, panel["gad"], panel["phq"])):
        cx = plot_left + (index + 0.5) * slot
        positions = [
            (cx - pair_gap / 2 - bar_width, gad_value, BLUE),
            (cx + pair_gap / 2, phq_value, RED),
        ]

        for bar_x, value, color in positions:
            bar_y = plot_bottom - value / panel["ymax"] * plot_height
            draw_rect(bar_x, bar_y, bar_width, plot_bottom - bar_y,
                      color, radius=7)
            draw_text(bar_x + bar_width / 2, bar_y - 23,
                      f"{value:,}", 29, weight="500")

        draw_multiline(cx, plot_bottom + 32, (score, severity), 26, 33)

draw_text(W / 2, 82, "GAD-7 与 PHQ-9 症状分层的整合比较", 66, weight="500")

legend_y = 158
legend_x = W / 2 - 320
draw_rect(legend_x, legend_y - 22, 52, 42, BLUE, radius=6)
draw_text(legend_x + 75, legend_y, "GAD-7", 32, anchor="start")
legend_x2 = W / 2 + 80
draw_rect(legend_x2, legend_y - 22, 52, 42, RED, radius=6)
draw_text(legend_x2 + 75, legend_y, "PHQ-9", 32, anchor="start")

draw_panel(PANELS[0], 245, 1000)
draw_panel(PANELS[1], 1090, 1845)

draw_rect(150, 1885, 2720, 125, NOTE_BG, radius=20)
draw_text(190, 1925,
          "≥15为统一合并口径：GAD-7对应15–21分（重度）；PHQ-9对应15–27分（中重度及重度）。",
          28, fill=MUTED, anchor="start")
draw_text(190, 1972,
          "PHQ-9三模态匹配后的重度组为59人，已排除1名来自单一站点的被试。",
          28, fill=MUTED, anchor="start")

png_path = OUT_DIR / "gad_phq_integrated_barplots.png"
pdf_path = OUT_DIR / "gad_phq_integrated_barplots.pdf"
svg_path = OUT_DIR / "gad_phq_integrated_barplots.svg"

image.save(png_path, dpi=(300, 300), optimize=True)
image.save(pdf_path, "PDF", resolution=300.0)
ET.ElementTree(svg).write(svg_path, encoding="utf-8", xml_declaration=True)

print(png_path)
print(pdf_path)
print(svg_path)
