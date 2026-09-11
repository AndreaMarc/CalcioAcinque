using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;
using System.Text;
using CalcioAcinque.Backend.Configuration;
using CalcioAcinque.Backend.Middleware;
using CalcioAcinque.Backend.Services;
using CalcioAcinque.Backend.Services.Push;
using Lib.Net.Http.WebPush;

// Generazione delle chiavi VAPID: si lancia una volta sola e si mettono in env,
// cosi la chiave privata non finisce nel repo.
//   dotnet run --project Backend -- --generate-vapid
if (args.Contains("--generate-vapid"))
{
    var (pub, priv) = VapidKeyGenerator.Generate();
    Console.WriteLine("Chiavi VAPID generate. Impostale come variabili d ambiente del backend:");
    Console.WriteLine();
    Console.WriteLine($"  Push__VapidPublicKey={pub}");
    Console.WriteLine($"  Push__VapidPrivateKey={priv}");
    Console.WriteLine($"  Push__Subject=mailto:tuaemail@esempio.it");
    Console.WriteLine();
    Console.WriteLine("La pubblica finisce anche nel browser (e ok). La privata NO: tienila solo lato server.");
    return;
}

var builder = WebApplication.CreateBuilder(args);

// Configurazione database MySQL
var connectionString = builder.Configuration.GetConnectionString("DefaultConnection");
var mysqlVersion = new MySqlServerVersion(new Version(8, 0, 36));
builder.Services.AddDbContext<ApplicationDbContext>(options =>
    options.UseMySql(connectionString, mysqlVersion));

// Registra Services
builder.Services.AddScoped<IAuthService, AuthService>();
builder.Services.AddScoped<ITeamService, TeamService>();
builder.Services.AddScoped<IClubService, ClubService>();
builder.Services.AddScoped<INotificationService, NotificationService>();

// Notifiche push (Web Push, RFC 8291/8292)
builder.Services.Configure<PushOptions>(builder.Configuration.GetSection(PushOptions.SectionName));
builder.Services.AddHttpClient<PushServiceClient>();
builder.Services.AddScoped<IWebPushSender, WebPushSender>();
builder.Services.AddHostedService<NotificationDispatcher>();
builder.Services.AddHostedService<MatchReminderService>();
builder.Services.AddScoped<IPlayerService, PlayerService>();
builder.Services.AddScoped<IMatchService, MatchService>();
builder.Services.AddScoped<IConvocationService, ConvocationService>();
builder.Services.AddScoped<IAttendanceService, AttendanceService>();
builder.Services.AddScoped<ITokenService, TokenService>();
builder.Services.AddScoped<IPaymentService, PaymentService>();
builder.Services.AddScoped<IMatchPaymentService, MatchPaymentService>();
builder.Services.AddScoped<ISeasonService, SeasonService>();
builder.Services.AddScoped<IDashboardService, DashboardService>();
builder.Services.AddScoped<IAvailabilityService, AvailabilityService>();
builder.Services.AddScoped<IStatsService, StatsService>();
builder.Services.AddScoped<IAnnouncementService, AnnouncementService>();
builder.Services.AddScoped<ITeamDraftService, TeamDraftService>();

// Configurazione JWT Authentication
var jwtKey = builder.Configuration["Jwt:Key"] ?? throw new InvalidOperationException("JWT Key non configurata");
// La chiave in appsettings.json e' SOLO per lo sviluppo: in produzione arriva da
// Jwt__Key (env, vedi docker-compose.yml). Se manca, meglio non partire che
// firmare i token con una chiave che sta nel repository.
if (!builder.Environment.IsDevelopment() && (jwtKey.StartsWith("DEV_ONLY", StringComparison.Ordinal) || jwtKey.Length < 32))
    throw new InvalidOperationException("Jwt:Key di sviluppo o troppo corta: in produzione va passata con la variabile d'ambiente Jwt__Key");
var jwtIssuer = builder.Configuration["Jwt:Issuer"];
var jwtAudience = builder.Configuration["Jwt:Audience"];

builder.Services.AddAuthentication(options =>
{
    options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
})
.AddJwtBearer(options =>
{
    options.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuer = true,
        ValidateAudience = true,
        ValidateLifetime = true,
        ValidateIssuerSigningKey = true,
        ValidIssuer = jwtIssuer,
        ValidAudience = jwtAudience,
        IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtKey)),
        ClockSkew = TimeSpan.Zero
    };
});

builder.Services.AddAuthorization();

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc("v1", new OpenApiInfo
    {
        Title = "InCampo API",
        Version = "v1",
        Description = "API InCampo - convocazioni, presenze, gettoni e quote per squadre di calcio a 5, 7, 8 e 11"
    });

    options.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Name = "Authorization",
        Type = SecuritySchemeType.Http,
        Scheme = "Bearer",
        BearerFormat = "JWT",
        In = ParameterLocation.Header,
        Description = "Inserisci il token JWT nel formato: Bearer {token}"
    });

    options.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        {
            new OpenApiSecurityScheme
            {
                Reference = new OpenApiReference
                {
                    Type = ReferenceType.SecurityScheme,
                    Id = "Bearer"
                }
            },
            Array.Empty<string>()
        }
    });
});

// CORS configuration
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowFrontend", policy =>
    {
        if (builder.Environment.IsDevelopment())
        {
            policy.SetIsOriginAllowed(_ => true)
                  .AllowAnyHeader()
                  .AllowAnyMethod()
                  .AllowCredentials();
        }
        else
        {
            // In produzione consenti solo l'origin del frontend
            var allowedOrigins = (builder.Configuration["Cors:AllowedOrigins"]
                                  ?? "https://incampo.studiorocket.it")
                .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
            policy.WithOrigins(allowedOrigins)
                  .AllowAnyHeader()
                  .AllowAnyMethod()
                  .AllowCredentials();
        }
    });
});

var app = builder.Build();

// Apply migrations and seed database
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
    await db.Database.MigrateAsync();
    // I dati demo (admin@incampo.it / admin123) solo in sviluppo o se richiesti
    // esplicitamente: un database di produzione ricreato non deve nascere con
    // credenziali note.
    if (app.Environment.IsDevelopment() || builder.Configuration.GetValue<bool>("Seed:Demo"))
        await DatabaseSeeder.SeedAsync(db);
}

// Configure the HTTP request pipeline
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI(c =>
    {
        c.SwaggerEndpoint("/swagger/v1/swagger.json", "InCampo API v1");
        c.RoutePrefix = string.Empty;
    });
}
// Niente UseHttpsRedirection/UseHsts: il TLS lo termina Traefik davanti al
// container, e senza porta https configurata il middleware loggava solo
// "Failed to determine the https port for redirect" a ogni richiesta.

// Security header minimo lato API
app.Use(async (ctx, next) =>
{
    ctx.Response.Headers["X-Content-Type-Options"] = "nosniff";
    await next();
});

app.UseMiddleware<ExceptionHandlingMiddleware>();
app.UseCors("AllowFrontend");
app.UseAuthentication();
app.UseAuthorization();
app.UseMiddleware<TeamAuthorizationMiddleware>();
app.MapControllers();

// Health check endpoint
app.MapGet("/health", () => Results.Ok(new
{
    status = "healthy",
    timestamp = DateTime.UtcNow,
    service = "InCampo API"
}));

app.Run();
