"""Generate original branding and a silent offline introduction. Run in .venv."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import math
import subprocess
import imageio_ffmpeg

ROOT = Path(__file__).resolve().parents[1]
BRAND = ROOT / 'assets/branding'
VIDEO = ROOT / 'assets/videos'
BRAND.mkdir(parents=True, exist_ok=True)
VIDEO.mkdir(parents=True, exist_ok=True)
TEAL = '#126B63'
FONT = Path('C:/Windows/Fonts/segoeuib.ttf')
def font(size): return ImageFont.truetype(str(FONT), size)

def mark(size, background=True):
    image = Image.new('RGBA', (1024, 1024), TEAL if background else (0, 0, 0, 0))
    d = ImageDraw.Draw(image)
    d.ellipse((244, 176, 780, 712), fill='#F5F6E9')
    d.polygon([(294, 600), (512, 850), (730, 600)], fill='#F5F6E9')
    for x, y, r in [(414, 374, 54), (602, 374, 54), (508, 485, 34)]:
        d.ellipse((x-r, y-r, x+r, y+r), fill=TEAL)
    d.rounded_rectangle((330, 448, 462, 602), 58, fill=TEAL)
    d.rounded_rectangle((554, 448, 688, 602), 58, fill=TEAL)
    d.rounded_rectangle((470, 535, 546, 652), 36, fill=TEAL)
    return image.resize((size, size), Image.Resampling.LANCZOS)

mark(1024).save(BRAND / 'icon.png')
mark(256).save(BRAND / 'icon_preview.png')
for density, size in [('mdpi',48),('hdpi',72),('xhdpi',96),('xxhdpi',144),('xxxhdpi',192)]:
    mark(size).save(ROOT / f'android/app/src/main/res/mipmap-{density}/ic_launcher.png')
# Adaptive layers stay inside Android's safe area, including round launchers.
res = ROOT / 'android/app/src/main/res'
for directory in ['drawable', 'mipmap-anydpi-v26']: (res/directory).mkdir(exist_ok=True)
layer = Image.new('RGBA', (432,432))
layer.alpha_composite(mark(252, False), (90,90))
layer.save(res/'drawable/launcher_foreground.png')
(res/'mipmap-anydpi-v26/ic_launcher.xml').write_text('''<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
  <background android:drawable="@color/launcher_background" />
  <foreground android:drawable="@drawable/launcher_foreground" />
</adaptive-icon>\n''')
(res/'values/launcher_colors.xml').write_text('<resources><color name="launcher_background">#126B63</color></resources>\n')
# Keep iOS icon filenames and catalog mapping intact.
import json
catalog = ROOT/'ios/Runner/Assets.xcassets/AppIcon.appiconset'
if catalog.exists():
    for entry in json.loads((catalog/'Contents.json').read_text())['images']:
        if 'filename' in entry:
            pixels = round(float(entry['size'].split('x')[0])*float(entry['scale'].rstrip('x')))
            mark(pixels).convert('RGB').save(catalog/entry['filename'])

W, H = 720, 576
def frame(t):
    im = Image.new('RGB', (W,H), '#E7F3EF')
    d = ImageDraw.Draw(im)
    for box in [(30,95,270,275),(415,30,675,180),(445,340,705,530)]:
        d.rounded_rectangle(box, 38, fill='#CFE4D8')
    paths = [[(-40,360),(230,360),(350,190),(770,190)],[(145,-20),(145,210),(390,460),(390,610)],[(590,-20),(590,280),(270,540),(-20,540)]]
    for pts in paths:
        d.line(pts, fill='#FAFCF6', width=42, joint='curve')
        d.line(pts, fill='#FFFFFF', width=3, joint='curve')
    d.rounded_rectangle((278,238,442,340),24,fill='white')
    d.polygon([(320,282),(360,250),(400,282)], fill=TEAL)
    d.rounded_rectangle((328,280,392,319),8,fill=TEAL)
    d.rectangle((352,297,367,319),fill='white')
    # A restrained travelling dot joins the two family members.
    for i in range(18):
        x=190+i*19; y=400-i*8
        d.ellipse((x-3,y-3,x+3,y+3),fill='#A4C5BB')
    s=(math.sin(t*math.pi/3-math.pi/2)+1)/2
    x=190+323*s; y=400-136*s
    d.ellipse((x-7,y-7,x+7,y+7),fill=TEAL)
    for x,y,label,color,phase in [(190,400,'A',TEAL,0),(532,256,'M','#D48853',1.4)]:
        r=44+5*math.sin(t*2+phase)
        d.ellipse((x-r-9,y-r-9,x+r+9,y+r+9),outline='#B9D8CC',width=2)
        d.ellipse((x-40,y-40,x+40,y+40),fill='white')
        d.ellipse((x-33,y-33,x+33,y+33),fill=color)
        d.text((x,y-2),label,font=font(28),anchor='mm',fill='white')
    d.rounded_rectangle((35,480,300,545),22,fill='white')
    d.ellipse((51,501,67,517),fill=TEAL)
    d.text((82,500),'Together, even from here.',font=font(17),fill=TEAL)
    return im

frame(2).save(BRAND/'intro_poster.png')
encoder = imageio_ffmpeg.get_ffmpeg_exe()
command=[encoder,'-y','-f','rawvideo','-vcodec','rawvideo','-s',f'{W}x{H}','-pix_fmt','rgb24','-r','24','-i','-','-an','-c:v','libx264','-preset','medium','-crf','25','-pix_fmt','yuv420p','-movflags','+faststart',str(VIDEO/'family_intro.mp4')]
process=subprocess.Popen(command,stdin=subprocess.PIPE,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
for i in range(144): process.stdin.write(frame(i/24).tobytes())
process.stdin.close()
error=process.stderr.read()
if process.wait(): raise RuntimeError(error.decode())
print('Generated six-second H.264 introduction and Android/iOS launcher icons.')
