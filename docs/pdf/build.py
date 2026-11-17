"""Markdown -> styled HTML for the GT App Data Feature Map PDF.

    python3 build.py <input.md> <output.html> <fonts-dir>

Pandoc does the Markdown conversion; this script reshapes the HTML so
style.css can lay it out (key-value tables, the overview table, one
page per data-source block, inline SVG figures) and fills in the date
and font paths.
"""
import pathlib
import re
import subprocess
import sys

here = pathlib.Path(__file__).resolve().parent
src, out_html, font_dir = (pathlib.Path(arg) for arg in sys.argv[1:4])

raw = src.read_text()
date_match = re.search(r"Last updated (\w+ \d{1,2}, \d{4})", raw)
if not date_match:
    sys.exit('build.py: no "Last updated <Month D, YYYY>" line found in ' + str(src))

body = subprocess.run(
    ["pandoc", str(src), "-f", "markdown", "-t", "html5", "--wrap=none"],
    capture_output=True, text=True, check=True).stdout

body = re.sub(r"<colgroup>.*?</colgroup>", "", body, flags=re.S)
body = re.sub(r'\sstyle="[^"]*"', "", body)


def tag_kv(match):
    """Key-value tables have an empty header row; drop it and tag the table."""
    table = match.group(0)
    empty_header = re.search(
        r"<thead>\s*<tr[^>]*>\s*(<th[^>]*></th>\s*)+</tr>\s*</thead>", table)
    if "<thead" not in table or empty_header:
        table = re.sub(r"<thead>.*?</thead>", "", table, flags=re.S)
        return table.replace("<table", '<table class="kv"', 1)
    return table


body = re.sub(r"<table>.*?</table>", tag_kv, body, flags=re.S)

# The overview table is the first remaining table with six header cells.
for m in re.finditer(r"<table>(.*?)</table>", body, flags=re.S):
    if m.group(1).count("<th") == 6:
        body = (body[:m.start()] + '<table class="glance">' + m.group(1)
                + "</table>" + body[m.end():])
        break

# The storage-region table needs a wider last column.
body = re.sub(
    r"<table>((?:(?!</table>).)*?<th[^>]*>Region</th>.*?)</table>",
    r'<table class="stored">\1</table>', body, flags=re.S)

# Keep each numbered data-source heading with its table on one page. A
# heading followed by a figure keeps heading and figure together; the
# table after it is taller than the room left on the page, so it may
# continue on the next page between rows. The heading pattern must not
# run past its own </h3>, or a block would swallow the next section.
H3 = r"<h3[^>]*>\d+\. (?:(?!</h3>).)*</h3>"
body = re.sub(
    rf'({H3}\s*<figure>.*?</figure>)(\s*<table class="kv">.*?</table>)',
    r'<div class="src">\1</div>\2', body, flags=re.S)
body = re.sub(
    rf'({H3}\s*<table class="kv">.*?</table>)',
    r'<div class="src">\1</div>', body, flags=re.S)

# The first two paragraphs are the subtitle and intro; they go in the masthead.
paras = list(re.finditer(r"<p>(.*?)</p>", body, flags=re.S))
subtitle, intro = paras[0].group(1), paras[1].group(1)
body = body[:paras[0].start()] + body[paras[1].end():]


# Figures: inline each referenced SVG so it uses the page's embedded Roboto
# (an <img> SVG can't see the page's @font-face). Done last, because the
# style-attribute strip above would otherwise damage the diagrams.
def inline_svg(match):
    path = (src.parent / match.group(1)).resolve()
    if not path.is_file():
        sys.exit(f"build.py: figure not found: {path}")
    return path.read_text().strip()


body = re.sub(r'<img src="([^"]+\.svg)"[^>]*>', inline_svg, body)
body = re.sub(r"<figcaption[^>]*>(Figure \d+\.)", r"<figcaption><strong>\1</strong>", body)

css = ((here / "style.css").read_text()
       .replace("__DATE__", date_match.group(1))
       .replace("__FONT_DIR__", font_dir.resolve().as_uri()))

out_html.write_text(f"""<!doctype html><html lang="en"><head><meta charset="utf-8"><title>GT App Data Feature Map</title>
<style>{css}</style></head><body>
<div class="masthead">
<p class="eyebrow">GT iOS Club &nbsp;·&nbsp; In partnership with SGA</p>
<h1>GT App Data Feature Map</h1>
<p class="subtitle">{subtitle}</p>
<p class="intro">{intro}</p>
</div>
{body}
</body></html>""")
