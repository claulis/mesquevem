# Generates the launcher icons: python3 tool/make_icon.py
from PIL import Image, ImageDraw

S = 1024
img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
d.rounded_rectangle([0, 0, S - 1, S - 1], radius=230, fill=(46, 125, 50))  # green 800

W = (255, 255, 255)
w = 56
# cart: handle, basket, wheels
d.line([(170, 300), (270, 300), (360, 640), (760, 640)], fill=W, width=w, joint="curve")
d.polygon([(290, 380), (820, 380), (760, 580), (345, 580)], fill=W)
for x in (400, 710):
    d.ellipse([x - 52, 700, x + 52, 804], fill=W)
# up-trend arrow inside basket (forecast)
G = (46, 125, 50)
d.line([(390, 530), (510, 450), (580, 500), (700, 420)], fill=G, width=34, joint="curve")
d.polygon([(735, 395), (655, 405), (715, 465)], fill=G)

sizes = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
for k, px in sizes.items():
    img.resize((px, px), Image.LANCZOS).save(f"android/app/src/main/res/mipmap-{k}/ic_launcher.png")
img.save("tool/icon_1024.png")
