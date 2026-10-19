from pathlib import Path
from PIL import Image, ImageDraw, ImageFont


OUT_DIR = Path(__file__).resolve().parent / "outputs"
OUT_DIR.mkdir(exist_ok=True)

W, H = 4800, 2700
BG = "#FFFFFF"
TEXT = "#202124"
MUTED = "#5F6368"
GRID = "#D9DEE5"
BLUE = "#377EB8"
RED = "#E41A1C"
RED_DARK = "#A50F15"
FONT_PATH = "/System/Library/Fonts/STHeiti Medium.ttc"


def font(size):
    return ImageFont.truetype(FONT_PATH, size=size)


F_TITLE = font(92)
F_PANEL = font(64)
F_AXIS = font(43)
F_TICK = font(39)
F_VALUE = font(39)
F_PERCENT = font(33)
F_LEGEND = font(43)
F_NOTE = font(37)
F_INSET_TITLE = font(38)
F_INSET_TICK = font(31)
F_INSET_VALUE = font(29)


gad = {
    "title": "A  GAD-7 焦虑症状分层",
    "labels": [
        "0–4\n无或极轻微", "5–9\n轻度", "10–14\n中度", "15–21\n重度",
    ],
    "all": [3212, 1477, 506, 148],
    "matched": [1847, 854, 277, 85],
    "ymax": 3600,
    "step": 500,
}

phq = {
    "title": "B  PHQ-9 抑郁症状分层",
    "labels": [
        "0–4\n无或极轻微", "5–9\n轻度", "10–14\n中度", "15–27\n中重度及以上",
    ],
    "all": [2922, 1522, 603, 316],
    "matched": [1680, 875, 346, 173],
    "ymax": 3300,
    "step": 500,
    "inset": {
        "title": "合并组构成",
        "labels": ["15–19\n中重度", "20–27\n重度"],
        "all": [209, 107],
        "matched": [114, 59],
        "ymax": 240,
    },
}


img = Image.new("RGB", (W, H), BG)
d = ImageDraw.Draw(img)


def centered_text(x, y, text, fnt, fill=TEXT):
    box = d.multiline_textbbox((0, 0), text, font=fnt, align="center", spacing=8)
    width = box[2] - box[0]
    d.multiline_text((x - width / 2, y), text, font=fnt, fill=fill,
                     align="center", spacing=8)


def draw_panel(panel, left, top, right, bottom):
    title_y = top
    d.text((left, title_y), panel["title"], font=F_PANEL, fill=TEXT)

    plot_left = left + 165
    plot_right = right - 45
    plot_top = top + 150
    plot_bottom = bottom - 260
    plot_w = plot_right - plot_left
    plot_h = plot_bottom - plot_top

    for value in range(0, panel["ymax"] + 1, panel["step"]):
        y = plot_bottom - value / panel["ymax"] * plot_h
        d.line((plot_left, y, plot_right, y), fill=GRID, width=3)
        label = f"{value:,}"
        box = d.textbbox((0, 0), label, font=F_TICK)
        d.text((plot_left - 25 - (box[2] - box[0]), y - (box[3] - box[1]) / 2),
               label, font=F_TICK, fill=MUTED)

    d.line((plot_left, plot_top, plot_left, plot_bottom), fill=TEXT, width=4)
    d.line((plot_left, plot_bottom, plot_right, plot_bottom), fill=TEXT, width=4)

    n = len(panel["labels"])
    slot = plot_w / n
    bar_w = min(115, slot * 0.28)
    gap = 12

    for i, (label, total, matched) in enumerate(
            zip(panel["labels"], panel["all"], panel["matched"])):
        cx = plot_left + (i + 0.5) * slot
        x1a, x1b = cx - gap / 2 - bar_w, cx - gap / 2
        x2a, x2b = cx + gap / 2, cx + gap / 2 + bar_w
        y1 = plot_bottom - total / panel["ymax"] * plot_h
        y2 = plot_bottom - matched / panel["ymax"] * plot_h
        d.rounded_rectangle((x1a, y1, x1b, plot_bottom), radius=10, fill=BLUE)
        d.rounded_rectangle((x2a, y2, x2b, plot_bottom), radius=10, fill=RED)

        centered_text((x1a + x1b) / 2, y1 - 58, f"{total:,}", F_VALUE)
        centered_text((x2a + x2b) / 2, y2 - 58, f"{matched:,}", F_VALUE)
        retention = matched / total * 100
        centered_text((x2a + x2b) / 2, y2 - 108, f"{retention:.1f}%", F_PERCENT,
                      RED_DARK)
        centered_text(cx, plot_bottom + 35, label, F_TICK)

    if "inset" in panel:
        inset = panel["inset"]
        il = int(plot_left + plot_w * 0.52)
        ir = int(plot_right - 25)
        it = int(plot_top + 60)
        ib = int(plot_top + 690)
        d.rounded_rectangle((il, it, ir, ib), radius=20, fill="#FFFFFF",
                            outline="#AAB2BD", width=3)
        centered_text((il + ir) / 2, it + 20, inset["title"], F_INSET_TITLE)

        ml, mr = il + 90, ir - 30
        mt, mb = it + 115, ib - 115
        for value in [0, 100, 200]:
            y = mb - value / inset["ymax"] * (mb - mt)
            d.line((ml, y, mr, y), fill="#E3E7EC", width=2)
            label = str(value)
            box = d.textbbox((0, 0), label, font=F_INSET_TICK)
            d.text((ml - 15 - (box[2] - box[0]), y - 15), label,
                   font=F_INSET_TICK, fill=MUTED)
        d.line((ml, mt, ml, mb), fill=MUTED, width=3)
        d.line((ml, mb, mr, mb), fill=MUTED, width=3)

        mini_slot = (mr - ml) / 2
        mini_w = 54
        mini_gap = 10
        for j, (label, total, matched) in enumerate(zip(
                inset["labels"], inset["all"], inset["matched"])):
            cx = ml + (j + 0.5) * mini_slot
            x1a, x1b = cx - mini_gap / 2 - mini_w, cx - mini_gap / 2
            x2a, x2b = cx + mini_gap / 2, cx + mini_gap / 2 + mini_w
            y1 = mb - total / inset["ymax"] * (mb - mt)
            y2 = mb - matched / inset["ymax"] * (mb - mt)
            d.rounded_rectangle((x1a, y1, x1b, mb), radius=6, fill=BLUE)
            d.rounded_rectangle((x2a, y2, x2b, mb), radius=6, fill=RED)
            centered_text((x1a + x1b) / 2, y1 - 39, str(total), F_INSET_VALUE)
            centered_text((x2a + x2b) / 2, y2 - 39, str(matched), F_INSET_VALUE)
            centered_text(cx, mb + 18, label, F_INSET_TICK)

    label = "被试人数"
    box = d.textbbox((0, 0), label, font=F_AXIS)
    layer = Image.new("RGBA", (box[2] - box[0] + 20, box[3] - box[1] + 20), (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    ld.text((10, 10), label, font=F_AXIS, fill=TEXT)
    layer = layer.rotate(90, expand=True)
    img.paste(layer, (left + 5, int((plot_top + plot_bottom - layer.height) / 2)), layer)


d.text((W / 2, 80), "GAD-7 与 PHQ-9 各症状阶段的被试人数",
       font=F_TITLE, fill=TEXT, anchor="ma")

legend_y = 225
legend_x = W / 2 - 520
d.rounded_rectangle((legend_x, legend_y, legend_x + 75, legend_y + 48), radius=8, fill=BLUE)
d.text((legend_x + 100, legend_y - 2), "量表可用总样本", font=F_LEGEND, fill=TEXT)
legend_x2 = W / 2 + 80
d.rounded_rectangle((legend_x2, legend_y, legend_x2 + 75, legend_y + 48), radius=8, fill=RED)
d.text((legend_x2 + 100, legend_y - 2), "与三模态数据匹配后", font=F_LEGEND, fill=TEXT)

draw_panel(gad, 100, 355, 2370, 2265)
draw_panel(phq, 2430, 355, 4700, 2265)

note1 = "注：图中仅展示各症状严重程度分层，不包含 <10 与 ≥10 的汇总人数。"
note2 = "PHQ-9 中重度及以上组为 15–19 组与 20–27 组合并结果；插图展示其构成，重度组已排除 1 名单一站点被试。"
d.rounded_rectangle((150, 2350, 4650, 2615), radius=28, fill="#F5F7FA")
d.text((220, 2390), note1, font=F_NOTE, fill=MUTED)
d.text((220, 2482), note2, font=F_NOTE, fill=MUTED)

png_path = OUT_DIR / "gad_phq_subject_counts.png"
pdf_path = OUT_DIR / "gad_phq_subject_counts.pdf"
img.save(png_path, dpi=(300, 300), optimize=True)
img.save(pdf_path, "PDF", resolution=300.0)
print(png_path)
print(pdf_path)
