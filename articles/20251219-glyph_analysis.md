---
title: "PDF 埋め込みフォントの独自エンコーディング調査"
emoji: "🔠"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["python", "pdf", "font", "pymupdf", "freetype"]
published: true
---

PDF に独自エンコーディングのフォントが使用されている場合、テキストをコピー＆ペーストすると見た目と異なる文字になってしまいます。このような PDF からフォントを抽出して調査するための要素技術を、Python による最小実装と共に解説します。

:::message
PDF が暗号化されている場合にも同様な現象は発生しますが、本記事では対象外とします。
:::
:::message
本記事は Gemini 3 Flash の生成結果をベースに、Claude Code と手動で編集しました。
:::

## 準備

依存ライブラリをインストールします。uv での例を示します。

```bash
uv add pymupdf freetype-py https://github.com/sbamboo/python-sixel.git
```

Sixel については以下の記事を参照してください。

https://qiita.com/7shi/items/69d1e7c15c7c6a5bb34f

## フォントの抽出

PDF 内部に格納されているフォントファイルを抽出します。

```python
import fitz  # PyMuPDF

pdf = fitz.open("document.pdf")
for page in pdf:
    for font in page.get_fonts(full=True):
        xref = font[0]
        # フォント名、拡張子、データ本体を取得
        name, ext, _, data = pdf.extract_font(xref)
        if data:
            filename = f"{name}.{ext}"
            with open(filename, "wb") as f:
                f.write(data)
            print(f"Extracted font: {filename}")
```

## 文字コードとグリフ ID の対応を特定

フォント内部で、どの文字コードがどのグリフ ID (GID) を指し示しているかを確認します。

```python
import freetype

face = freetype.Face("font.cff")
for i, (code, gid) in enumerate(face.get_chars(), start=1):
    print(f"{i}: U+{code:04X}, gid={gid}")
```

## フォントデータからグリフを描画

FreeType で生成したビットマップを、Pillow の Image オブジェクトに変換します。

```python
from PIL import Image

def render_glyph(face, gid):
    face.set_char_size(64 * 64)  # 64px 相当
    face.load_glyph(gid)
    bmp = face.glyph.bitmap

    # FreeType のバッファを Pillow の画像オブジェクトに変換
    return Image.frombytes("L", (bmp.width, bmp.rows), bytes(bmp.buffer))
```

## Sixel によるターミナル上でのプレビュー

大量のグリフを調査する際、1枚ずつ画像ファイルを保存すると煩雑なため、Sixel でターミナルに直接表示します。先ほど実装した `render_glyph` を使用します。

```python
import io
import sys
import sixel
import freetype

def show_sixel(image):
    with io.BytesIO() as buf:
        image.save(buf, format="PNG")
        sixel.converter.SixelConverter(buf).write(sys.stdout)

face = freetype.Face("font.cff")
for i, (code, gid) in enumerate(face.get_chars(), start=1):
    print(f"{i}: U+{code:04X}, gid={gid}", end=" ")
    image = render_glyph(face, gid)
    show_sixel(image)
    print()
```

## フォントメトリクスを用いた垂直位置制御

このままでは表示されるグリフの高さ (height) がまちまちで、実際の表示位置に沿っていません。事前にすべてのグリフのメトリクス情報を読み取って、ベースラインを揃えて表示する必要があります。

```python
import freetype
from PIL import Image

# すべてのグリフのメトリクス情報を収集
face = freetype.Face("font.cff")
font_size = 64
face.set_char_size(font_size * font_size)
ascender = 0
descender = 0
for code, gid in face.get_chars():
    face.load_glyph(gid)
    metrics = face.glyph.metrics
    bearing_y = metrics.horiBearingY / font_size
    height = metrics.height / font_size
    ascender = max(ascender, bearing_y)
    descender = max(descender, height - bearing_y)

# render_glyph をベースライン揃えに対応させる
def render_glyph(face, gid):
    face.load_glyph(gid)
    bmp = face.glyph.bitmap
    glyph_img = Image.frombytes("L", (bmp.width, bmp.rows), bytes(bmp.buffer))

    # キャンバスを作成してグリフを正しい位置に配置
    canvas = Image.new("L", (bmp.width, int(ascender + descender)))
    metrics = face.glyph.metrics
    bearing_y = metrics.horiBearingY / font_size
    canvas.paste(glyph_img, (0, int(ascender - bearing_y)))

    return canvas
```

フォントメトリクスのイメージ図（`Aq` の例）：

```text
┌──────────────┐ ─── ascender line
│   █          │  ↑
│  █ █         │  │
│ █   █        │  │  ascender
│ █   █   ████ │  │
│ █████  █   █ │  │
│ █   █  █   █ │  ↓
├─█───█───████─┤ ─── baseline
│            █ │  ↑
│            █ │  │  descender
│            █ │  ↓
└──────────────┘ ─── descender line
```

## 画像を埋め込んだ HTML の生成

Sixel によってターミナル内でグリフの形状が確認できるようになりましたが、ログの保存に問題があります。

- Windows Terminal ではコピー＆ペーストに画像が含まれない
- 出力をファイルにリダイレクトした場合、Sixel のエスケープシーケンスがそのまま含まれてしまう

1つのファイルにまとめて出力すると取り回しが便利なため、画像を Base64 で埋め込んだ HTML を生成します。

```python
import base64
import io

def to_data_url(image):
    buf = io.BytesIO()
    image.save(buf, format="PNG")
    b64 = base64.b64encode(buf.getvalue()).decode()
    return f"data:image/png;base64,{b64}"

# HTML の初期化
html = '<!DOCTYPE html>\n<html>\n<head>\n<meta charset="UTF-8">\n</head>\n<body>\n'

face = freetype.Face("font.cff")
for i, (code, gid) in enumerate(face.get_chars(), start=1):
    glyph_info = f"{i}: U+{code:04X}, gid={gid}"

    # ターミナルに出力
    print(glyph_info, end=" ")
    image = render_glyph(face, gid)
    show_sixel(image)
    print()

    # HTML に追加
    data_url = to_data_url(image)
    html += f'<p>{glyph_info} <img src="{data_url}"></p>\n'

html += '</body>\n</html>\n'

# 生成した HTML を保存
with open("report.html", "w", encoding="utf-8") as f:
    f.write(html)
print("Saved HTML: report.html")
```

`print` と `html +=` を併記することで、ターミナルでの確認と HTML レポートの生成を同時に行います。画像は Base64 エンコードして HTML に直接埋め込むため、外部ファイルへの依存がありません。

編集が必要であれば、出力された HTML をブラウザで開いて、Word などにコピー＆ペーストすることで対応できます。

:::message
文字数が多いと Word へのペーストに時間が掛かります。
:::

## まとめ

これらの技術を組み合わせた調査フローは以下の通りです。

1.  PDF に埋め込まれたフォントを抽出
2.  ターミナルにグリフを表示
3.  ログを HTML として出力

## 関連記事

画像を含んだログを扱うため、C# で RichTextBox を使用したことがありました。

https://qiita.com/7shi/items/cf9f7a8f0d53e6b6c841
