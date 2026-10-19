from pathlib import Path
import xml.etree.ElementTree as ET


OUT_DIR = Path(__file__).resolve().parent / "outputs"
OUT_DIR.mkdir(exist_ok=True)

W, H = 2000, 1500
TEXT = "#202124"
MUTED = "#5F6368"
BORDER = "#D5DAE1"
HEADER = "#F1F3F5"
BLUE = "#377EB8"
BLUE_LIGHT = "#EAF3FA"
RED = "#E41A1C"
RED_LIGHT = "#FDEBEC"
WHITE = "#FFFFFF"
FONT = "STHeiti, 'PingFang SC', 'Microsoft YaHei', Arial, sans-serif"

GAD_ROWS_ALL = [
    ("0–4", "无或极轻微", 3212),
    ("5–9", "轻度", 1477),
    ("10–14", "中度", 506),
    ("15–21", "重度", 148),
]
PHQ_ROWS_ALL = [
    ("0–4", "无或极轻微", 2922),
    ("5–9", "轻度", 1522),
    ("10–14", "中度", 603),
    ("15–19", "中重度", 209),
    ("20–27", "重度", 107),
]
GAD_ROWS_MATCHED = [
    ("0–4", "无或极轻微", 1847),
    ("5–9", "轻度", 854),
    ("10–14", "中度", 277),
    ("15–21", "重度", 85),
]
PHQ_ROWS_MATCHED = [
    ("0–4", "无或极轻微", 1680),
    ("5–9", "轻度", 875),
    ("10–14", "中度", 346),
    ("15–19", "中重度", 114),
    ("20–27", "重度", 59),
]


def add_text(svg, x, y, value, size, fill=TEXT, anchor="middle", weight="400"):
    node = ET.SubElement(svg, "text", {
        "x": str(x), "y": str(y), "fill": fill,
        "font-family": FONT, "font-size": str(size),
        "font-weight": weight, "text-anchor": anchor,
    })
    node.text = value


def add_rect(svg, x, y, width, height, fill, stroke=None, stroke_width=0, rx=0):
    attrs = {
        "x": str(x), "y": str(y), "width": str(width), "height": str(height),
        "fill": fill, "rx": str(rx),
    }
    if stroke:
        attrs.update({"stroke": stroke, "stroke-width": str(stroke_width)})
    ET.SubElement(svg, "rect", attrs)


def draw_subtable(svg, x, y, width, metric, rows, color, light):
    band_h, head_h, row_h = 112, 96, 112
    col_widths = [230, 330, width - 560]
    total = sum(row[2] for row in rows)
    table_rows = rows + [("", "合计", total)]
    total_height = band_h + head_h + row_h * len(table_rows)

    add_rect(svg, x, y, width, total_height, WHITE, BORDER, 3, 16)
    add_rect(svg, x, y, width, band_h, color, rx=16)
    add_rect(svg, x, y + band_h - 16, width, 16, color)
    add_text(svg, x + 34, y + 72, metric, 48, WHITE, anchor="start", weight="500")
    add_text(svg, x + width - 34, y + 70, "症状严重程度划分", 30,
             WHITE, anchor="end")

    header_y = y + band_h
    add_rect(svg, x, header_y, width, head_h, HEADER)
    headers = ["分数范围", "症状等级", "被试人数（n）"]
    cursor = x
    for col_width, header in zip(col_widths, headers):
        add_text(svg, cursor + col_width / 2, header_y + 62, header, 34, weight="500")
        cursor += col_width

    row_y = header_y + head_h
    for index, (score, severity, count) in enumerate(table_rows):
        is_total = index == len(table_rows) - 1
        is_high = (metric == "GAD-7" and severity in {"中度", "重度"}) or (
            metric == "PHQ-9" and severity in {"中度", "中重度", "重度"}
        )
        fill = light if is_high and not is_total else ("#F7F8FA" if is_total else WHITE)
        add_rect(svg, x, row_y, width, row_h, fill)
        if is_high and not is_total:
            add_rect(svg, x, row_y, 10, row_h, color)
        if is_total:
            add_text(svg, x + col_widths[0] / 2, row_y + 71, "—", 34, MUTED)
        else:
            add_text(svg, x + col_widths[0] / 2, row_y + 71, score, 36)
        add_text(svg, x + col_widths[0] + col_widths[1] / 2,
                 row_y + 71, severity, 36, weight="500" if is_total else "400")
        add_text(svg, x + col_widths[0] + col_widths[1] + col_widths[2] / 2,
                 row_y + 71, f"{count:,}", 38, color, weight="500")
        row_y += row_h

    cursor = x
    for col_width in col_widths[:-1]:
        cursor += col_width
        ET.SubElement(svg, "line", {
            "x1": str(cursor), "y1": str(header_y),
            "x2": str(cursor), "y2": str(y + total_height),
            "stroke": BORDER, "stroke-width": "2",
        })
    for i in range(len(table_rows) + 1):
        yy = header_y + head_h + i * row_h
        ET.SubElement(svg, "line", {
            "x1": str(x), "y1": str(yy), "x2": str(x + width), "y2": str(yy),
            "stroke": BORDER, "stroke-width": "2",
        })


def make_table(filename, title, subtitle, gad_rows, phq_rows, note):
    ET.register_namespace("", "http://www.w3.org/2000/svg")
    svg = ET.Element("svg", {
        "xmlns": "http://www.w3.org/2000/svg",
        "width": str(W), "height": str(H), "viewBox": f"0 0 {W} {H}",
        "role": "img", "aria-labelledby": "title desc",
    })
    ET.SubElement(svg, "title", {"id": "title"}).text = title
    ET.SubElement(svg, "desc", {"id": "desc"}).text = (
        "蓝色表格为GAD-7，红色表格为PHQ-9，分别展示分数范围、症状等级和被试人数。"
    )
    add_rect(svg, 0, 0, W, H, WHITE)
    add_text(svg, W / 2, 105, title, 66, weight="500")
    add_text(svg, W / 2, 163, subtitle, 32, MUTED)

    draw_subtable(svg, 70, 225, 880, "GAD-7", gad_rows, BLUE, BLUE_LIGHT)
    draw_subtable(svg, 1050, 225, 880, "PHQ-9", phq_rows, RED, RED_LIGHT)

    add_rect(svg, 70, 1245, 1860, 190, "#F5F7FA", rx=18)
    add_text(svg, 105, 1310,
             "分层差异：GAD-7 为中度（10–14）和重度（15–21）；PHQ-9 为中度（10–14）、中重度（15–19）和重度（20–27）。",
             31, MUTED, anchor="start")
    add_text(svg, 105, 1375, note, 31, MUTED, anchor="start")

    out_path = OUT_DIR / filename
    ET.ElementTree(svg).write(out_path, encoding="utf-8", xml_declaration=True)
    return out_path


all_path = make_table(
    "all_subjects_severity_table.svg",
    "所有被试的 GAD-7 与 PHQ-9 症状分层",
    "按量表可用被试统计",
    GAD_ROWS_ALL,
    PHQ_ROWS_ALL,
    "两种量表的可用样本数不同：GAD-7 合计 5,343 人，PHQ-9 合计 5,363 人。",
)

matched_path = make_table(
    "trimodal_matched_severity_table.svg",
    "三模态匹配后的 GAD-7 与 PHQ-9 症状分层",
    "仅统计同时具有三模态数据的被试",
    GAD_ROWS_MATCHED,
    PHQ_ROWS_MATCHED,
    "GAD-7 合计 3,063 人；PHQ-9 分层合计 3,074 人，其中重度组已排除 1 名单一站点被试。",
)

print(all_path)
print(matched_path)
