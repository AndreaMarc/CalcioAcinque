namespace CalcioAcinque.Backend.DTOs.Auth;

public class UpdatePreferencesRequest
{
    /// <summary>null = non toccare.</summary>
    public bool? TemaScuro { get; set; }

    /// <summary>"#RRGGBB"; stringa vuota per tornare al verde di default, null = non toccare.</summary>
    public string? ColoreBrand { get; set; }
}
