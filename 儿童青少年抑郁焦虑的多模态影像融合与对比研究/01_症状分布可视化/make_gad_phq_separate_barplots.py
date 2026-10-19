from pathlib import Path
import xml.etree.ElementTree as ET

from PIL import Image, ImageDraw, ImageFont


OUT_DIR = Path(__file__).resolve().parent / "outputs"
OUT_DIR.mkdir(exist_ok=True)

W, H = 2800, 1450
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

FIGURES = [
    {
        "filename": "all_subjects_gad_phq_barplot",
        "title": "所有量表被试的 GAD-7 与 PHQ-9 症状分层",
        "subtitle": "GAD-7 n = 5,343；PHQ-9 n = 5,363",
        "gad": [3212, 1477, 506, 148],
        "phq": [2922, 1522, 603, 316],
        "ymax": 3500,
        "step": 500,
        "note": "≥15统一口径：GAD-7为15–21分（重度）；PHQ-9为15–27分（中重度及重度）。",
    },
    {
        "filename": "trimodal_matched_gad_phq_barplot",
        "title": "三模态匹配后的 GAD-7 与 PHQ-9 症状分层",
        "subtitle": "GAD-7 n = 3,063；PHQ-9 n = 3,074",
        "gad": [1847, 854, 277, 85],
        "phq": [1680, 875, 346, 173],
        "ymax": 2000,
        "step": 500,
        "note": "≥15统一口径：GAD-7为15–21分；PHQ-9为15–27分。PHQ-9重度组已排除1名单一站点被试。",
    },
]


def render_figure(spec):
    image = Image.new("RGB", (W, H), WHITE)
    canvas = ImageDraw.Draw(image)
    font_cache = {}

    ET.register_namespace("", "http://www.w3.org/2000/svg")
    svg = ET.Element("svg", {
        "xmlns": "http://www.w3.org/2000/svg",
        "width": str(W), "height": str(H), "viewBox": f"0 0 {W} {H}",
        "role": "img", "aria-labelledby": "title desc",
    })
    ET.SubElement(svg, "title", {"id": "title"}).text = spec["title"]
    ET.SubElement(svg, "desc", {"id": "desc"}).text = (
        "浅蓝色柱为GAD-7，浅红色柱为PHQ-9，按四个共同分数段成对展示。"
    )
    ET.SubElement(svg, "rect", {
        "x": "0", "y": "0", "width": str(W), "height": str(H), "fill": WHITE,
    })

    def get_font(size):
        if size not in font_cache:
            font_cache[size] = ImageFont.truetype(FONT_PATH, size=size)
        return font_cache[size]

    def text(x, y, value, size, fill=TEXT, anchor="middle", weight="400"):
        pil_anchor = {"middle": "mm", "start": "lm", "end": "rm"}[anchor]
        canvas.text((x, y), value, font=get_font(size), fill=fill, anchor=pil_anchor)
        ET.SubElement(svg, "text", {
            "x": f"{x:.1f}", "y": f"{y:.1f}", "fill": fill,
            "font-family": FONT_FAMILY, "font-size": str(size),
            "font-weight": weight, "text-anchor": anchor,
            "dominant-baseline": "middle",
        }).text = value

    def line(x1, y1, x2, y2, fill, width=2):
        canvas.line((x1, y1, x2, y2), fill=fill, width=width)
        ET.SubElement(svg, "line", {
            "x1": f"{x1:.1f}", "y1": f"{y1:.1f}",
            "x2": f"{x2:.1f}", "y2": f"{y2:.1f}",
            "stroke": fill, "stroke-width": str(width),
        })

    def rect(x, y, width, height, fill, radius=0):
        canvas.rounded_rectangle((x, y, x + width, y + height),
                                 radius=radius, fill=fill)
        ET.SubElement(svg, "rect", {
            "x": f"{x:.1f}", "y": f"{y:.1f}",
            "width": f"{width:.1f}", "height": f"{height:.1f}",
            "fill": fill, "rx": str(radius),
        })

    text(W / 2, 78, spec["title"], 62, weight="500")
    text(W / 2, 145, spec["subtitle"], 31, fill=MUTED)

    legend_y = 215
    legend_x = W / 2 - 330
    rect(legend_x, legend_y - 21, 52, 42, BLUE, radius=6)
    text(legend_x + 75, legend_y, "GAD-7", 31, anchor="start")
    legend_x2 = W / 2 + 85
    rect(legend_x2, legend_y - 21, 52, 42, RED, radius=6)
    text(legend_x2 + 75, legend_y, "PHQ-9", 31, anchor="start")

    plot_left, plot_right = 210, 2680
    plot_top, plot_bottom = 330, 1110
    plot_width = plot_right - plot_left
    plot_height = plot_bottom - plot_top

    text(plot_left, plot_top - 35, "被试人数（n）", 28,
         fill=MUTED, anchor="start")
    tick = 0
    while tick <= spec["ymax"]:
        yy = plot_bottom - tick / spec["ymax"] * plot_height
        line(plot_left, yy, plot_right, yy, GRID, 2)
        text(plot_left - 20, yy, f"{tick:,}", 28,
             fill=MUTED, anchor="end")
        tick += spec["step"]
    line(plot_left, plot_top, plot_left, plot_bottom, TEXT, 3)
    line(plot_left, plot_bottom, plot_right, plot_bottom, TEXT, 3)

    slot = plot_width / len(CATEGORIES)
    bar_width = 145
    gap = 12
    for index, ((score, severity), gad_value, phq_value) in enumerate(zip(
            CATEGORIES, spec["gad"], spec["phq"])):
        cx = plot_left + (index + 0.5) * slot
        bars = [
            (cx - gap / 2 - bar_width, gad_value, BLUE),
            (cx + gap / 2, phq_value, RED),
        ]
        for bar_x, value, color in bars:
            bar_y = plot_bottom - value / spec["ymax"] * plot_height
            rect(bar_x, bar_y, bar_width, plot_bottom - bar_y, color, radius=8)
            text(bar_x + bar_width / 2, bar_y - 25,
                 f"{value:,}", 31, weight="500")
        text(cx, plot_bottom + 40, score, 29)
        text(cx, plot_bottom + 80, severity, 29)

    rect(160, 1250, 2480, 115, NOTE_BG, radius=20)
    text(200, 1307, spec["note"], 28, fill=MUTED, anchor="start")

    base = OUT_DIR / spec["filename"]
    png_path = base.with_suffix(".png")
    pdf_path = base.with_suffix(".pdf")
    svg_path = base.with_suffix(".svg")
    image.save(png_path, dpi=(300, 300), optimize=True)
    image.save(pdf_path, "PDF", resolution=300.0)
    ET.ElementTree(svg).write(svg_path, encoding="utf-8", xml_declaration=True)
    return png_path, pdf_path, svg_path


for figure in FIGURES:
    for output in render_figure(figure):
        print(output)
