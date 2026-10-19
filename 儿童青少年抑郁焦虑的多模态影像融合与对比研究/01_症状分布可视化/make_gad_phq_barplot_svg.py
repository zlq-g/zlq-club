from pathlib import Path
import xml.etree.ElementTree as ET


OUT_DIR = Path(__file__).resolve().parent / "outputs"
OUT_DIR.mkdir(exist_ok=True)

W, H = 4800, 2700
TEXT = "#202124"
MUTED = "#5F6368"
GRID = "#D9DEE5"
BLUE = "#377EB8"
RED = "#E41A1C"
RED_DARK = "#A50F15"
FONT = "STHeiti, 'PingFang SC', 'Microsoft YaHei', Arial, sans-serif"

gad = {
    "title": "A  GAD-7 焦虑症状分层",
    "labels": [("0–4", "无或极轻微"), ("5–9", "轻度"),
               ("10–14", "中度"), ("15–21", "重度")],
    "all": [3212, 1477, 506, 148],
    "matched": [1847, 854, 277, 85],
    "ymax": 3600,
    "step": 500,
}

phq = {
    "title": "B  PHQ-9 抑郁症状分层",
    "labels": [("0–4", "无或极轻微"), ("5–9", "轻度"),
               ("10–14", "中度"), ("15–27", "中重度及以上")],
    "all": [2922, 1522, 603, 316],
    "matched": [1680, 875, 346, 173],
    "ymax": 3300,
    "step": 500,
    "inset": {
        "title": "合并组构成",
        "labels": [("15–19", "中重度"), ("20–27", "重度")],
        "all": [209, 107],
        "matched": [114, 59],
        "ymax": 240,
    },
}


ET.register_namespace("", "http://www.w3.org/2000/svg")
svg = ET.Element("svg", {
    "xmlns": "http://www.w3.org/2000/svg",
    "width": str(W), "height": str(H),
    "viewBox": f"0 0 {W} {H}",
    "role": "img",
    "aria-labelledby": "title desc",
})
ET.SubElement(svg, "title", {"id": "title"}).text = "GAD-7 与 PHQ-9 各症状阶段的被试人数"
ET.SubElement(svg, "desc", {"id": "desc"}).text = (
    "蓝色表示量表可用总样本，红色表示与三模态数据匹配后的样本；"
    "PHQ-9 中重度与重度合并，并用插图展示构成。"
)
ET.SubElement(svg, "rect", {"x": "0", "y": "0", "width": str(W),
                            "height": str(H), "fill": "#FFFFFF"})


def line(x1, y1, x2, y2, stroke, width=3):
    ET.SubElement(svg, "line", {
        "x1": f"{x1:.1f}", "y1": f"{y1:.1f}",
        "x2": f"{x2:.1f}", "y2": f"{y2:.1f}",
        "stroke": stroke, "stroke-width": str(width),
    })


def rect(x, y, width, height, fill, rx=0, stroke=None, stroke_width=0):
    attrs = {
        "x": f"{x:.1f}", "y": f"{y:.1f}",
        "width": f"{width:.1f}", "height": f"{height:.1f}",
        "fill": fill, "rx": str(rx),
    }
    if stroke:
        attrs.update({"stroke": stroke, "stroke-width": str(stroke_width)})
    ET.SubElement(svg, "rect", attrs)


def text(x, y, value, size, fill=TEXT, anchor="middle", weight="400",
         transform=None):
    attrs = {
        "x": f"{x:.1f}", "y": f"{y:.1f}", "fill": fill,
        "font-family": FONT, "font-size": str(size),
        "font-weight": weight, "text-anchor": anchor,
    }
    if transform:
        attrs["transform"] = transform
    node = ET.SubElement(svg, "text", attrs)
    node.text = value
    return node


def multiline_text(x, y, lines, size, fill=TEXT, gap=48):
    node = text(x, y, "", size, fill=fill)
    for index, value in enumerate(lines):
        tspan = ET.SubElement(node, "tspan", {
            "x": f"{x:.1f}", "dy": "0" if index == 0 else str(gap),
        })
        tspan.text = value


def draw_inset(inset, il, it, ir, ib):
    rect(il, it, ir - il, ib - it, "#FFFFFF", rx=20,
         stroke="#AAB2BD", stroke_width=3)
    text((il + ir) / 2, it + 55, inset["title"], 38)
    ml, mr = il + 90, ir - 30
    mt, mb = it + 115, ib - 115
    for value in (0, 100, 200):
        y = mb - value / inset["ymax"] * (mb - mt)
        line(ml, y, mr, y, "#E3E7EC", 2)
        text(ml - 15, y + 11, str(value), 31, fill=MUTED, anchor="end")
    line(ml, mt, ml, mb, MUTED, 3)
    line(ml, mb, mr, mb, MUTED, 3)
    slot = (mr - ml) / 2
    bar_w, gap = 54, 10
    for i, (label, total, matched) in enumerate(zip(
            inset["labels"], inset["all"], inset["matched"])):
        cx = ml + (i + 0.5) * slot
        x1 = cx - gap / 2 - bar_w
        x2 = cx + gap / 2
        y1 = mb - total / inset["ymax"] * (mb - mt)
        y2 = mb - matched / inset["ymax"] * (mb - mt)
        rect(x1, y1, bar_w, mb - y1, BLUE, rx=6)
        rect(x2, y2, bar_w, mb - y2, RED, rx=6)
        text(x1 + bar_w / 2, y1 - 14, str(total), 29)
        text(x2 + bar_w / 2, y2 - 14, str(matched), 29)
        multiline_text(cx, mb + 42, label, 31, gap=38)


def draw_panel(panel, left, top, right, bottom):
    text(left, top + 60, panel["title"], 64, anchor="start", weight="500")
    plot_left = left + 165
    plot_right = right - 45
    plot_top = top + 150
    plot_bottom = bottom - 260
    plot_w = plot_right - plot_left
    plot_h = plot_bottom - plot_top

    value = 0
    while value <= panel["ymax"]:
        y = plot_bottom - value / panel["ymax"] * plot_h
        line(plot_left, y, plot_right, y, GRID, 3)
        text(plot_left - 25, y + 14, f"{value:,}", 39,
             fill=MUTED, anchor="end")
        value += panel["step"]
    line(plot_left, plot_top, plot_left, plot_bottom, TEXT, 4)
    line(plot_left, plot_bottom, plot_right, plot_bottom, TEXT, 4)

    n = len(panel["labels"])
    slot = plot_w / n
    bar_w = min(115, slot * 0.28)
    gap = 12
    for i, (label, total, matched) in enumerate(zip(
            panel["labels"], panel["all"], panel["matched"])):
        cx = plot_left + (i + 0.5) * slot
        x1 = cx - gap / 2 - bar_w
        x2 = cx + gap / 2
        y1 = plot_bottom - total / panel["ymax"] * plot_h
        y2 = plot_bottom - matched / panel["ymax"] * plot_h
        rect(x1, y1, bar_w, plot_bottom - y1, BLUE, rx=10)
        rect(x2, y2, bar_w, plot_bottom - y2, RED, rx=10)
        text(x1 + bar_w / 2, y1 - 20, f"{total:,}", 39)
        text(x2 + bar_w / 2, y2 - 20, f"{matched:,}", 39)
        text(x2 + bar_w / 2, y2 - 70, f"{matched / total * 100:.1f}%",
             33, fill=RED_DARK)
        multiline_text(cx, plot_bottom + 70, label, 39, gap=48)

    ylabel_x = left + 55
    ylabel_y = (plot_top + plot_bottom) / 2
    text(ylabel_x, ylabel_y, "被试人数", 43,
         transform=f"rotate(-90 {ylabel_x:.1f} {ylabel_y:.1f})")

    if "inset" in panel:
        draw_inset(panel["inset"], int(plot_left + plot_w * 0.52),
                   int(plot_top + 60), int(plot_right - 25),
                   int(plot_top + 690))


text(W / 2, 150, "GAD-7 与 PHQ-9 各症状阶段的被试人数", 92, weight="500")
legend_y = 225
legend_x = W / 2 - 520
rect(legend_x, legend_y, 75, 48, BLUE, rx=8)
text(legend_x + 100, legend_y + 40, "量表可用总样本", 43, anchor="start")
legend_x2 = W / 2 + 80
rect(legend_x2, legend_y, 75, 48, RED, rx=8)
text(legend_x2 + 100, legend_y + 40, "与三模态数据匹配后", 43, anchor="start")

draw_panel(gad, 100, 355, 2370, 2265)
draw_panel(phq, 2430, 355, 4700, 2265)

rect(150, 2350, 4500, 265, "#F5F7FA", rx=28)
text(220, 2440, "注：图中仅展示各症状严重程度分层，不包含 <10 与 ≥10 的汇总人数。",
     37, fill=MUTED, anchor="start")
text(220, 2532,
     "PHQ-9 中重度及以上组为 15–19 组与 20–27 组合并结果；插图展示其构成，重度组已排除 1 名单一站点被试。",
     37, fill=MUTED, anchor="start")

out_path = OUT_DIR / "gad_phq_subject_counts.svg"
ET.ElementTree(svg).write(out_path, encoding="utf-8", xml_declaration=True)
print(out_path)
