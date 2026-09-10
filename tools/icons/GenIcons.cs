#:package SkiaSharp@3.119.1
#:package SkiaSharp.NativeAssets.Win32@3.119.1

// Genera le icone PWA / favicon / apple-touch-icon di InCampo.
//
//   dotnet run tools/icons/GenIcons.cs            (dalla radice del repo)
//
// La geometria e' la stessa di Frontend/lib/widgets/brand_mark.dart e di
// Frontend/web/icons/brand.svg (viewBox 100). Ridisegnare in Skia invece di
// rasterizzare l'SVG da' tratti piu' nitidi alle dimensioni piccole.
// L'output e' deterministico: rigenerare non deve produrre diff.

using SkiaSharp;

var root = FindRepoRoot();
var web = Path.Combine(root, "Frontend", "web");
var icons = Path.Combine(web, "icons");
Directory.CreateDirectory(icons);

var jobs = new (string path, int size, Mode mode)[]
{
    (Path.Combine(icons, "Icon-192.png"), 192, Mode.Rounded),
    (Path.Combine(icons, "Icon-512.png"), 512, Mode.Rounded),
    (Path.Combine(icons, "Icon-maskable-192.png"), 192, Mode.Maskable),
    (Path.Combine(icons, "Icon-maskable-512.png"), 512, Mode.Maskable),
    // iOS applica da solo la maschera arrotondata: niente angoli, niente alpha.
    (Path.Combine(icons, "apple-touch-icon.png"), 180, Mode.Square),
    (Path.Combine(icons, "favicon-32.png"), 32, Mode.Rounded),
    (Path.Combine(web, "favicon.png"), 48, Mode.Rounded),
};

foreach (var (path, size, mode) in jobs)
{
    using var bmp = new SKBitmap(size, size, SKColorType.Rgba8888, SKAlphaType.Premul);
    using var canvas = new SKCanvas(bmp);
    Draw(canvas, size, mode);
    using var img = SKImage.FromBitmap(bmp);
    using var data = img.Encode(SKEncodedImageFormat.Png, 100);
    File.WriteAllBytes(path, data.ToArray());
    Console.WriteLine($"{Path.GetRelativePath(root, path)}  {size}x{size}  {data.Size} B");
}

static void Draw(SKCanvas c, int size, Mode mode)
{
    var brand = SKColor.Parse("#00D27F");
    var ink = SKColor.Parse("#0A0E0F");
    float u = size / 100f;

    c.Clear(SKColors.Transparent);

    using var bg = new SKPaint { Color = brand, IsAntialias = true };
    var full = new SKRect(0, 0, size, size);
    if (mode == Mode.Rounded)
        c.DrawRoundRect(full, 26 * u, 26 * u, bg);
    else
        c.DrawRect(full, bg);

    // Maskable: la zona sicura e' il cerchio inscritto all'80%, il glifo va ridotto.
    float scale = mode == Mode.Maskable ? 0.66f : 1f;
    c.Translate(size * (1 - scale) / 2, size * (1 - scale) / 2);
    c.Scale(scale);

    using var stroke = new SKPaint
    {
        Color = ink,
        IsAntialias = true,
        Style = SKPaintStyle.Stroke,
        StrokeWidth = 7 * u,
        StrokeCap = SKStrokeCap.Round,
    };
    // Linea di meta' campo, interrotta dal cerchio di centrocampo
    c.DrawLine(14 * u, 50 * u, 27 * u, 50 * u, stroke);
    c.DrawLine(73 * u, 50 * u, 86 * u, 50 * u, stroke);
    // Cerchio di centrocampo
    c.DrawCircle(50 * u, 50 * u, 19 * u, stroke);
    // Dischetto
    using var fill = new SKPaint { Color = ink, IsAntialias = true };
    c.DrawCircle(50 * u, 50 * u, 4.5f * u, fill);
}

static string FindRepoRoot()
{
    var dir = new DirectoryInfo(Directory.GetCurrentDirectory());
    while (dir != null && !File.Exists(Path.Combine(dir.FullName, "docker-compose.yml")))
        dir = dir.Parent;
    return dir?.FullName ?? throw new InvalidOperationException("Eseguire dentro il repo (non trovo docker-compose.yml).");
}

enum Mode { Rounded, Square, Maskable }
