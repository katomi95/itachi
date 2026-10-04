"""main.gd に出てくる文字だけを Noto Sans JP Bold から切り出す(SIL OFL)。
    python tools/make_font.py <NotoSansJP[wght].ttf>
文字を増やしたら再実行すること(足りない文字はWebで文字化けする)。
"""
import sys, os
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer
from fontTools import subset

here = os.path.dirname(os.path.abspath(__file__))
s = open(os.path.join(here, "..", "main.gd"), encoding="utf-8").read()
chars = set(c for c in s if ord(c) >= 32)
chars |= set(chr(c) for c in range(0x3040, 0x3100))
chars |= set("♪♥…～！？「」、。―　")
f = instancer.instantiateVariableFont(TTFont(sys.argv[1]), {"wght": 700})
opt = subset.Options(); opt.layout_features = ["*"]
sub = subset.Subsetter(opt); sub.populate(text="".join(chars)); sub.subset(f)
out = os.path.join(here, "..", "fonts", "NotoSansJP-Bold-subset.ttf")
f.save(out)
cm = TTFont(out).getBestCmap()
print("missing:", "".join(c for c in chars if ord(c) not in cm), "size", os.path.getsize(out))
