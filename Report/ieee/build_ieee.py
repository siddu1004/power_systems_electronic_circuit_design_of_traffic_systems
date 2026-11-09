"""Build the IEEE-format two-column paper (docx) from SITRA_IEEE_Paper.md."""
import re, subprocess, copy, sys
from docx import Document
from docx.shared import Pt, Inches, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.oxml.ns import qn
from docx.oxml import OxmlElement

PANDOC = r"C:\Users\saisi\AppData\Local\Pandoc\pandoc.exe"
D = "Report/ieee/"
FONT = "Times New Roman"

# label used in draft -> number in the old reference file
LABEL2OLD = {1: 1, 2: 2, 3: 3, 4: 4, 5: 6, 7: 7, 8: 11, 9: 18, 10: 19, 11: 10, 12: 24, 13: 25, 15: 8}


def load_refs():
    refs = {}
    for l in open("Report/sections/sec16_references.md", encoding="utf-8"):
        m = re.match(r"\[(\d+)\] (.*)", l.strip())
        if m:
            refs[int(m.group(1))] = m.group(2)
    return refs


def renumber(md):
    head, tail = md.split("# References {.unnumbered}")
    order = []

    def sub(m):
        n = int(m.group(1))
        if n not in LABEL2OLD:
            return m.group(0)
        if n not in order:
            order.append(n)
        return "[%d]" % (order.index(n) + 1)

    head = re.sub(r"\[(\d+)\]", sub, head)
    refs = load_refs()
    lines = []
    for i, n in enumerate(order, 1):
        lines.append("::: {custom-style=\"IEEE Ref\"}\n[%d] %s\n:::\n" % (i, refs[LABEL2OLD[n]]))
    return head + "# References {.unnumbered}\n\n" + "\n".join(lines), len(order)


def run_pandoc():
    md = open(D + "SITRA_IEEE_Paper.md", encoding="utf-8").read()
    md2, n = renumber(md)
    open(D + "_build.md", "w", encoding="utf-8").write(md2)
    subprocess.run([PANDOC, D + "_build.md", "-o", D + "_raw.docx", "--reference-doc=Report/ref.docx",
                    "--resource-path=" + D, "-f", "markdown+tex_math_dollars+pipe_tables+smart"], check=True)
    return n


def set_font(run_or_style, size, bold=None, italic=None):
    f = run_or_style.font
    f.name = FONT
    f.size = Pt(size)
    if bold is not None: f.bold = bold
    if italic is not None: f.italic = italic
    rpr = run_or_style.element.get_or_add_rPr() if hasattr(run_or_style.element, "get_or_add_rPr") else None
    if rpr is not None:
        rf = rpr.find(qn("w:rFonts"))
        if rf is None:
            rf = OxmlElement("w:rFonts"); rpr.append(rf)
        for a in ("w:ascii", "w:hAnsi", "w:cs", "w:eastAsia"):
            rf.set(qn(a), FONT)
        for a in ("w:asciiTheme", "w:hAnsiTheme", "w:cstheme", "w:eastAsiaTheme"):
            if rf.get(qn(a)) is not None: del rf.attrib[qn(a)]


def style_fmt(doc, name, size, align, bold=False, italic=False, before=0, after=0, first=0, caps=False, color=True):
    try:
        st = doc.styles[name]
    except KeyError:
        return
    set_font(st, size, bold, italic)
    st.font.small_caps = caps
    st.font.color.rgb = RGBColor(0, 0, 0)
    pf = st.paragraph_format
    pf.alignment = align
    pf.space_before = Pt(before); pf.space_after = Pt(after)
    pf.first_line_indent = Inches(first)
    pf.left_indent = Inches(0)
    pf.line_spacing = 1.0


def build():
    n_refs = run_pandoc()
    doc = Document(D + "_raw.docx")
    J, C, L = WD_ALIGN_PARAGRAPH.JUSTIFY, WD_ALIGN_PARAGRAPH.CENTER, WD_ALIGN_PARAGRAPH.LEFT

    # make sure custom styles exist and are based on Normal
    from docx.enum.style import WD_STYLE_TYPE
    for nm in ["IEEE Abstract", "IEEE Keywords", "IEEE Affiliation", "IEEE Table Source", "IEEE Ref"]:
        try:
            doc.styles[nm]
        except KeyError:
            doc.styles.add_style(nm, WD_STYLE_TYPE.PARAGRAPH).base_style = doc.styles["Normal"]

    style_fmt(doc, "Normal", 10, J)
    style_fmt(doc, "Body Text", 10, J, first=0.2)
    style_fmt(doc, "First Paragraph", 10, J, first=0.2)
    style_fmt(doc, "Compact", 8, L)
    style_fmt(doc, "Title", 22, C, after=6)
    style_fmt(doc, "Author", 10, C, after=2)
    style_fmt(doc, "IEEE Affiliation", 9, C, italic=True, after=8)
    style_fmt(doc, "IEEE Abstract", 9, J, bold=True, after=4)
    style_fmt(doc, "IEEE Keywords", 9, J, bold=True, after=4)
    style_fmt(doc, "Heading 1", 10, C, before=10, after=4, caps=True)
    style_fmt(doc, "Heading 2", 10, L, italic=True, before=6, after=2)
    style_fmt(doc, "Heading 3", 10, L, italic=True, before=4, after=2)
    style_fmt(doc, "Image Caption", 8, J, after=6)
    style_fmt(doc, "Table Caption", 8, C, before=2, after=3, caps=False)
    style_fmt(doc, "Captioned Figure", 8, C, before=4, after=2)
    style_fmt(doc, "IEEE Table Source", 7.5, L, italic=True, after=2)
    style_fmt(doc, "IEEE Ref", 8, J, after=2)
    doc.styles["IEEE Ref"].paragraph_format.left_indent = Inches(0.3)
    doc.styles["IEEE Ref"].paragraph_format.first_line_indent = Inches(-0.3)
    for s in ("Title", "Heading 1", "Heading 2", "Heading 3"):
        doc.styles[s].font.bold = (s == "Title")
    doc.styles["Heading 1"].font.bold = False
    # keep headings with the next paragraph
    for s in ("Heading 1", "Heading 2"):
        doc.styles[s].paragraph_format.keep_with_next = True

    body = doc.element.body
    sect_idx = None
    for i, p in enumerate(doc.paragraphs):
        if p.text.strip() == "@@SECBREAK@@":
            sect_idx = i
            break

    # --- section break: title block is single column, rest two columns
    sp = doc.paragraphs[sect_idx]
    for r in list(sp.runs): r._r.getparent().remove(r._r)
    pPr = sp._p.get_or_add_pPr()
    sectPr = OxmlElement("w:sectPr")
    typ = OxmlElement("w:type"); typ.set(qn("w:val"), "continuous"); sectPr.append(typ)

    def page(sp_):
        pg = OxmlElement("w:pgSz"); pg.set(qn("w:w"), "12240"); pg.set(qn("w:h"), "15840"); sp_.append(pg)
        m = OxmlElement("w:pgMar")
        for k, v in (("top", 1080), ("right", 900), ("bottom", 1440), ("left", 900), ("header", 720), ("footer", 720), ("gutter", 0)):
            m.set(qn("w:" + k), str(v))
        sp_.append(m)

    page(sectPr)
    cols = OxmlElement("w:cols"); cols.set(qn("w:num"), "1"); sectPr.append(cols)
    pPr.append(sectPr)
    sp.paragraph_format.space_after = Pt(0)

    final = body.find(qn("w:sectPr"))
    for ch in list(final):
        final.remove(ch)
    t2 = OxmlElement("w:type"); t2.set(qn("w:val"), "continuous"); final.append(t2)
    page(final)
    c2 = OxmlElement("w:cols"); c2.set(qn("w:num"), "2"); c2.set(qn("w:space"), "360"); final.append(c2)

    # --- headings: roman numerals already typed; uppercase handled by small caps
    # --- display equations: inline with centered tab and right-aligned number
    eq_no = 0
    M = "http://schemas.openxmlformats.org/officeDocument/2006/math"
    for p in doc.paragraphs:
        omp = p._p.findall("{%s}oMathPara" % M)
        if omp:
            eq_no += 1
            oMaths = []
            for op in omp:
                oMaths += op.findall("{%s}oMath" % M)
                p._p.remove(op)
            pf = p.paragraph_format
            pf.alignment = L; pf.first_line_indent = Inches(0); pf.space_before = Pt(3); pf.space_after = Pt(3)
            pPr = p._p.get_or_add_pPr()
            tabs = OxmlElement("w:tabs")
            for val, pos in (("center", 2400), ("right", 5000)):
                t = OxmlElement("w:tab"); t.set(qn("w:val"), val); t.set(qn("w:pos"), str(pos)); tabs.append(t)
            pPr.append(tabs)
            r1 = p.add_run("\t"); r1.font.name = FONT
            for om in oMaths:
                p._p.append(om)
            r2 = p.add_run("\t(%d)" % eq_no); set_font(r2, 10)

    # --- body paragraph fonts (direct run fonts left to style; ensure Times in runs and math)
    for p in doc.paragraphs:
        for r in p.runs:
            r.font.name = FONT
            rpr = r._r.get_or_add_rPr()
            rf = rpr.find(qn("w:rFonts"))
            if rf is None:
                rf = OxmlElement("w:rFonts"); rpr.append(rf)
            for a in ("w:ascii", "w:hAnsi", "w:cs", "w:eastAsia"):
                rf.set(qn(a), FONT)

    # --- code font for backticked paths: smaller
    for p in doc.paragraphs:
        for r in p.runs:
            if r.style is not None and r.style.name == "Verbatim Char":
                r.font.name = "Courier New"; r.font.size = Pt(8)
    try:
        vc = doc.styles["Verbatim Char"]; vc.font.name = "Courier New"; vc.font.size = Pt(8)
    except KeyError:
        pass

    # --- figure paragraphs: center, keep with caption; images already sized by pandoc
    for p in doc.paragraphs:
        if p._p.findall(".//" + qn("w:drawing")):
            p.paragraph_format.alignment = C
            p.paragraph_format.first_line_indent = Inches(0)
            p.paragraph_format.keep_with_next = True

    # --- tables: IEEE look (top/bottom/header rules), 7.5 pt, full column width
    for t in doc.tables:
        t.alignment = WD_TABLE_ALIGNMENT.CENTER
        t.autofit = True
        tblPr = t._tbl.tblPr
        for el in tblPr.findall(qn("w:tblBorders")): tblPr.remove(el)
        b = OxmlElement("w:tblBorders")
        for edge, sz in (("top", 8), ("bottom", 8)):
            e = OxmlElement("w:" + edge); e.set(qn("w:val"), "single"); e.set(qn("w:sz"), str(sz)); e.set(qn("w:color"), "000000"); b.append(e)
        tblPr.append(b)
        w = tblPr.find(qn("w:tblW"))
        if w is None:
            w = OxmlElement("w:tblW"); tblPr.append(w)
        w.set(qn("w:type"), "pct"); w.set(qn("w:w"), "5000")
        mar = OxmlElement("w:tblCellMar")
        for side in ("left", "right"):
            e = OxmlElement("w:" + side); e.set(qn("w:w"), "40"); e.set(qn("w:type"), "dxa"); mar.append(e)
        tblPr.append(mar)
        for ri, row in enumerate(t.rows):
            trPr = row._tr.get_or_add_trPr()
            cs = OxmlElement("w:cantSplit"); trPr.append(cs)
            for cell in row.cells:
                tcPr = cell._tc.get_or_add_tcPr()
                if ri == 0:
                    bd = OxmlElement("w:tcBorders")
                    e = OxmlElement("w:bottom"); e.set(qn("w:val"), "single"); e.set(qn("w:sz"), "4"); e.set(qn("w:color"), "000000"); bd.append(e)
                    tcPr.append(bd)
                for p in cell.paragraphs:
                    p.paragraph_format.alignment = L if cell is row.cells[0] else C
                    p.paragraph_format.first_line_indent = Inches(0)
                    p.paragraph_format.space_after = Pt(0)
                    for r in p.runs:
                        r.font.size = Pt(7.5); r.font.name = FONT
                        if ri == 0: r.font.bold = True

    # --- remove empty paragraphs
    for p in list(doc.paragraphs):
        if not p.text.strip() and not p._p.findall(".//" + qn("w:drawing")) and p._p.find(".//" + qn("w:sectPr")) is None \
                and p._p.find("{%s}oMath" % M) is None:
            p._p.getparent().remove(p._p)

    # --- footer page numbers
    sec = doc.sections[-1]
    fp = sec.footer.paragraphs[0] if sec.footer.paragraphs else sec.footer.add_paragraph()
    fp.alignment = C
    run = fp.add_run()
    for tag, txt in (("begin", None), (None, "PAGE"), ("end", None)):
        if tag:
            fc = OxmlElement("w:fldChar"); fc.set(qn("w:fldCharType"), tag); run._r.append(fc)
        else:
            it = OxmlElement("w:instrText"); it.set(qn("xml:space"), "preserve"); it.text = txt; run._r.append(it)
    set_font(run, 8)

    # core properties
    doc.core_properties.title = "Clearing Congestion in Circuit Time"
    doc.core_properties.author = ""
    doc.save(D + "SITRA_IEEE_Paper.docx")
    print("saved; equations:", eq_no, "refs:", n_refs)


if __name__ == "__main__":
    build()
