# Generates the launcher icons ("Mês que Vem", Brazilian flag colors): python3 tool/make_icon.py
from PIL import Image, ImageDraw

S = 1024
VERDE, AMARELO, AZUL, BRANCO = (0, 156, 59), (255, 223, 0), (0, 39, 118), (255, 255, 255)
img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
d.rounded_rectangle([0, 0, S - 1, S - 1], radius=230, fill=VERDE)
d.rounded_rectangle([190, 230, 834, 840], radius=60, fill=BRANCO)       # calendar
d.rectangle([190, 330, 834, 400], fill=AMARELO)                          # header band
for x in (330, 694):
    d.rounded_rectangle([x - 28, 160, x + 28, 300], radius=28, fill=AMARELO)  # rings
d.line([(290, 740), (440, 600), (540, 680), (720, 500)], fill=AZUL, width=48, joint="curve")
d.polygon([(770, 450), (650, 465), (755, 570)], fill=AZUL)               # up arrow

sizes = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
for k, px in sizes.items():
    img.resize((px, px), Image.LANCZOS).save(f"android/app/src/main/res/mipmap-{k}/ic_launcher.png")
img.save("tool/icon_1024.png")
