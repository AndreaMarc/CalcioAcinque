using System.Security.Cryptography;

namespace CalcioAcinque.Backend.Services.Push;

/// <summary>
/// Configurazione VAPID, letta da `Push:*`. In produzione arriva da variabili
/// d'ambiente (Push__VapidPrivateKey): la chiave privata non va nel repo.
/// Senza chiavi il push resta spento e l'app funziona come prima.
/// </summary>
public class PushOptions
{
    public const string SectionName = "Push";

    public string? VapidPublicKey { get; set; }
    public string? VapidPrivateKey { get; set; }

    /// <summary>Contatto richiesto da RFC 8292: "mailto:..." oppure un URL https.</summary>
    public string Subject { get; set; } = "mailto:admin@incampo.studiorocket.it";

    /// <summary>Ogni quanto il dispatcher svuota la coda.</summary>
    public int PollingSeconds { get; set; } = 10;

    /// <summary>Tentativi prima di dare la notifica per persa.</summary>
    public int MaxTentativi { get; set; } = 3;

    public bool IsConfigured =>
        !string.IsNullOrWhiteSpace(VapidPublicKey) && !string.IsNullOrWhiteSpace(VapidPrivateKey);
}

/// <summary>Generazione della coppia VAPID, usata da `dotnet run -- --generate-vapid`.</summary>
public static class VapidKeyGenerator
{
    public static (string PublicKey, string PrivateKey) Generate()
    {
        using var ecdsa = ECDsa.Create(ECCurve.NamedCurves.nistP256);
        var p = ecdsa.ExportParameters(true);

        // Punto non compresso: 0x04 || X(32) || Y(32)
        var publicKey = new byte[65];
        publicKey[0] = 0x04;
        p.Q.X!.CopyTo(publicKey, 1);
        p.Q.Y!.CopyTo(publicKey, 33);

        return (Base64Url(publicKey), Base64Url(p.D!));
    }

    private static string Base64Url(byte[] bytes) =>
        Convert.ToBase64String(bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_');
}
