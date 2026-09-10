"""Rigenera PDF e Word dei due manuali a partire dall'HTML in questa cartella.

    python docs/sorgenti/genera.py

Serve Chrome (per il PDF) e python-docx (`pip install python-docx`).
L'HTML e' lo stesso pubblicato come artifact: modificare quello, poi rilanciare
qui, cosi' pagina, PDF e Word restano allineati.
"""
import pathlib
import subprocess
import sys

QUI = pathlib.Path(__file__).parent
DOCS = QUI.parent
CHROME_CANDIDATI = [
    r"C:\Program Files\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
]

MANUALI = {
    "manuale-giocatore": "CalcioAcinque - Manuale giocatori",
    "manuale-staff": "CalcioAcinque - Manuale staff",
}

# L'artifact pubblicato avvolge il file in questo scheletro: per il PDF va
# ricreato uguale, altrimenti si stampa una pagina diversa da quella online.
SCHELETRO = """<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
  :root { color-scheme: light dark; }
  body { margin: 0; font: 14px system-ui, sans-serif; background: #FAFAF9; }
  img { max-width: 100%; }
  [hidden] { display: none !important; }
</style>
__HEAD__
</head>
<body>
__BODY__
</body>
</html>
"""


def trova_chrome():
    for c in CHROME_CANDIDATI:
        if pathlib.Path(c).exists():
            return c
    return None


def impacchetta(slug):
    raw = (QUI / f"{slug}.html").read_text(encoding="utf-8")
    taglio = raw.index("</style>") + len("</style>")
    out = QUI / f"_{slug}.completo.html"
    out.write_text(
        SCHELETRO.replace("__HEAD__", raw[:taglio]).replace("__BODY__", raw[taglio:]),
        encoding="utf-8",
    )
    return out


def in_pdf(chrome, pagina, destinazione):
    subprocess.run(
        [chrome, "--headless=new", "--disable-gpu", "--no-pdf-header-footer",
         "--virtual-time-budget=10000", f"--print-to-pdf={destinazione}", pagina.as_uri()],
        capture_output=True, timeout=180, check=False,
    )


def main():
    chrome = trova_chrome()
    for slug, titolo in MANUALI.items():
        pagina = impacchetta(slug)
        if chrome:
            pdf = DOCS / f"{titolo}.pdf"
            in_pdf(chrome, pagina, pdf)
            print(pdf.name, "ok" if pdf.exists() else "FALLITO")
        else:
            print("Chrome non trovato: salto i PDF")

    try:
        sys.path.insert(0, str(QUI))
        import todocx
    except ImportError:
        print("python-docx non installato: salto i Word (pip install python-docx)")
        return
    for slug, titolo in MANUALI.items():
        out = todocx.converti(QUI / f"{slug}.html", DOCS / f"{titolo}.docx", titolo)
        print(out.name, "ok")


if __name__ == "__main__":
    main()
