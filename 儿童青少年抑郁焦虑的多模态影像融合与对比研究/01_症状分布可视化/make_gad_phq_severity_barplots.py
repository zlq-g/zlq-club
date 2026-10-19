from pathlib import Path
import xml.etree.ElementTree as ET

from PIL import Image, ImageDraw, ImageFont


OUT_DIR = Path(__file__).resolve().parent / "outputs"
OUT_DIR.mkdir(exist_ok=True)

W, H = 3200, 2350
WHITE = "#FFFFFF"
TEXT = "#202124"
MUTED = "#5F6368"
GRID = "#D9DEE5"
BLUE = "#377EB8"
RED = "#E41A1C"
NOTE_BG = "#F5F7FA"
FONT_PATH = "/System/Library/Fonts/STHeiti Medium.ttc"
FONT_FAMILY = "STHeiti, 'PingFang SC', 'Microsoft YaHei', Arial, sans-serif"

DATA = [
    {
        "section": "A  所有量表被试",
        "ymax": 3500,
        "step": 500,
        "panels": [
            {
                "metric": "GAD-7", "total": 5343, "color": BLUE,
                "labels": [("0–4", "无或极轻微"), ("5–9", "轻度"),
                           ("10–14", "中度"), ("15–21", "重度")],
                "values": [3212, 1477, 506, 148],
            },
            {
                "metric": "PHQ-9", "total": 5363, "color": RED,
                "labels": [("0–4", "无或极轻微"), ("5–9", "轻度"),
                           ("10–14", "中度"), ("15–19", "中重度"),
                           ("20–27", "重度")],
                "values": [2922, 1522, 603, 209, 107],
            },
        ],
    },
    {
        "section": "B  三模态数据匹配后",
        "ymax": 2000,
        "step": 500,
        "panels": [
            {
                "metric": "GAD-7", "total": 3063, "color": BLUE,
                "labels": [("0–4", "无或极轻微"), ("5–9", "轻度"),
                           ("10–14", "中度"), ("15–21", "重度")],
                "values": [1847, 854, 277, 85],
            },
            {
                "metric": "PHQ-9", "total": 3074, "color": RED,
                "labels": [("0–4", "无或极轻微"), ("5–9", "轻度"),
                           ("10–14", "中度"), ("15–19", "中重度"),
                           ("20–27", "重度")],
                "values": [1680, 875, 346, 114, 59],
            },
        ],
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
ET.SubElement(svg, "title", {"id": "title"}).text = "GAD-7与PHQ-9症状分层的被试人数"
ET.SubElement(svg, "desc", {"id": "desc"}).text = (
    "四面板柱状图。上排为所有量表被试，下排为三模态匹配后被试；"
    "蓝色表示GAD-7，红色表示PHQ-9。"
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


def draw_line(x1, y1, x2, y2, fill, width=2):
    canvas.line((x1, y1, x2, y2), fill=fill, width=width)
    ET.SubElement(svg, "line", {
        "x1": f"{x1:.1f}", "y1": f"{y1:.1f}",
        "x2": f"{x2:.1f}", "y2": f"{y2:.1f}",
        "stroke": fill, "stroke-width": str(width),
    })


def draw_rect(x, y, width, height, fill, radius=0, stroke=None, stroke_width=0):
    canvas.rounded_rectangle((x, y, x + width, y + height), radius=radius,
                             fill=fill, outline=stroke, width=stroke_width)
    attrs = {
        "x": f"{x:.1f}", "y": f"{y:.1f}",
        "width": f"{width:.1f}", "height": f"{height:.1f}",
        "fill": fill, "rx": str(radius),
    }
    if stroke:
        attrs.update({"stroke": stroke, "stroke-width": str(stroke_width)})
    ET.SubElement(svg, "rect", attrs)


def draw_multiline(x, y, lines, size, gap, fill=TEXT):
    for index, line_value in enumerate(lines):
        draw_text(x, y + index * gap, line_value, size, fill=fill)


def draw_panel(panel, x, y, width, height, ymax, step):
    color = panel["color"]
    draw_text(x, y + 30, panel["metric"], 48, fill=color,
              anchor="start", weight="500")
    draw_text(x + width, y + 30, f"合计 n = {panel['total']:,}", 31,
              fill=MUTED, anchor="end")

    plot_left = x + 95
    plot_right = x + width - 20
    plot_top = y + 90
    plot_bottom = y + height - 125
    plot_width = plot_right - plot_left
    plot_height = plot_bottom - plot_top

    draw_text(plot_left, plot_top - 28, "被试人数（n）", 27,
              fill=MUTED, anchor="start")
    tick = 0
    while tick <= ymax:
        yy = plot_bottom - tick / ymax * plot_height
        draw_line(plot_left, yy, plot_right, yy, GRID, 2)
        draw_text(plot_left - 18, yy, f"{tick:,}", 27,
                  fill=MUTED, anchor="end")
        tick += step
    draw_line(plot_left, plot_top, plot_left, plot_bottom, TEXT, 3)
    draw_line(plot_left, plot_bottom, plot_right, plot_bottom, TEXT, 3)

    labels = panel["labels"]
    values = panel["values"]
    slot = plot_width / len(values)
    bar_width = min(150, slot * 0.48)
    for index, (label, value) in enumerate(zip(labels, values)):
        cx = plot_left + (index + 0.5) * slot
        bar_y = plot_bottom - value / ymax * plot_height
        draw_rect(cx - bar_width / 2, bar_y, bar_width,
                  plot_bottom - bar_y, color, radius=8)
        draw_text(cx, bar_y - 25, f"{value:,}", 32, weight="500")
        draw_multiline(cx, plot_bottom + 32, label, 27, 34)


draw_text(W / 2, 85, "GAD-7 与 PHQ-9 症状分层的被试人数", 68, weight="500")
draw_text(W / 2, 153, "蓝色：GAD-7　　红色：PHQ-9", 34, fill=MUTED)

panel_x = [120, 1650]
panel_width = 1430
panel_height = 760
row_y = [285, 1240]

for row_index, row in enumerate(DATA):
    heading_y = row_y[row_index] - 45
    draw_text(120, heading_y, row["section"], 45, anchor="start", weight="500")
    for panel_index, panel in enumerate(row["panels"]):
        draw_panel(panel, panel_x[panel_index], row_y[row_index],
                   panel_width, panel_height, row["ymax"], row["step"])

draw_rect(120, 2075, 2960, 205, NOTE_BG, radius=22)
draw_text(165, 2135,
          "分层差异：GAD-7 为中度（10–14）和重度（15–21）；PHQ-9 为中度（10–14）、中重度（15–19）和重度（20–27）。",
          30, fill=MUTED, anchor="start")
draw_text(165, 2205,
          "注：PHQ-9 三模态匹配后的重度组为 59 人，已排除 1 名来自单一站点的被试。",
          30, fill=MUTED, anchor="start")

png_path = OUT_DIR / "gad_phq_severity_barplots.png"
pdf_path = OUT_DIR / "gad_phq_severity_barplots.pdf"
svg_path = OUT_DIR / "gad_phq_severity_barplots.svg"

image.save(png_path, dpi=(300, 300), optimize=True)
image.save(pdf_path, "PDF", resolution=300.0)
ET.ElementTree(svg).write(svg_path, encoding="utf-8", xml_declaration=True)

print(png_path)
print(pdf_path)
print(svg_path)
