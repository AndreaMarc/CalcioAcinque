namespace CalcioAcinque.Backend.DTOs.Payments;

public class PlayerPaymentDto
{
    public int Id { get; set; }
    public int PlayerId { get; set; }
    public string NomeGiocatore { get; set; } = string.Empty;
    public string Descrizione { get; set; } = string.Empty;
    public decimal Importo { get; set; }
    public DateTime DataPagamento { get; set; }
    public bool Pagato { get; set; }
    public string? Note { get; set; }
    public string AdminNome { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
}

public class CreatePaymentDto
{
    public string Descrizione { get; set; } = string.Empty;
    public decimal Importo { get; set; }
    public DateTime DataPagamento { get; set; }
    public bool Pagato { get; set; } = false;
    public string? Note { get; set; }
}

public class UpdatePaymentDto
{
    public string? Descrizione { get; set; }
    public decimal? Importo { get; set; }
    public DateTime? DataPagamento { get; set; }
    public bool? Pagato { get; set; }
    public string? Note { get; set; }
}
