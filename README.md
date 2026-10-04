# いたちごっこ

**▶ 遊ぶ: https://katomi95.github.io/itachi/**

「いたち対策」をしても、なぜか毎回突破される1〜3分の一発ネタミニゲーム。Godot 4 製。
無駄に重厚な導入と、くだらない実態のギャップを楽しんでください。

- 操作: マウス(クリック)のみ。最初に「クリックでスタート」(音が出ます)
- 絵・BGM・SE はすべてコードで生成(外部素材なし)
- フォント: Noto Sans JP (SIL OFL)

## 開発
- Godot 4.4+ で `project.godot` を開く
- 音の再生成: `python tools/gen_audio.py` (numpy 必要)
- Web書き出し: プリセット `Web` → `docs/index.html`
