# ?? Application Performance Monitoring (APM) com Azure Application Insights

Este guia explica como o Application Insights está configurado no projeto FCG para monitoramento completo dos microsserviços.

---

## ?? **O que é Application Insights?**

Azure Application Insights é um serviço de APM (Application Performance Monitoring) que fornece:

- **Distributed Tracing**: Rastreamento de requisições através de múltiplos serviços
- **Performance Monitoring**: Tempo de resposta, throughput, latência
- **Failure Analysis**: Detecção e análise de exceções e falhas
- **Dependency Tracking**: Monitoramento de chamadas a bancos de dados, APIs, filas
- **Live Metrics**: Métricas em tempo real
- **Custom Metrics**: Métricas personalizadas de negócio
- **Logs Centralizados**: Todos os logs em um único lugar

---

## ??? **Arquitetura de Telemetria**

```
???????????????????????????????????????????
?     Application Insights (Azure)        ?
?                                         ?
?  ????????????????????????????????????? ?
?  ?  Telemetry Data                   ? ?
?  ?  • Requests                       ? ?
?  ?  • Dependencies (SQL, ServiceBus) ? ?
?  ?  • Exceptions                     ? ?
?  ?  ?  • Custom Events                ? ?
?  ?  • Traces (Logs)                  ? ?
?  ?  • Metrics                        ? ?
?  ????????????????????????????????????? ?
???????????????????????????????????????????
              ?
              ? SDK envia telemetria
              ?
    ?????????????????????
    ?         ?         ?
????????? ????????? ?????????????
?  FCG  ? ? Games ? ? Payments  ?
?  Pod  ? ?  Pod  ? ?    Pod    ?
????????? ????????? ?????????????
```

---

## ?? **Configuração no Kubernetes**

### **1. Secret com Credenciais**

O deploy cria automaticamente um secret:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: appinsights-secrets
data:
  ApplicationInsights__InstrumentationKey: <base64>
  ApplicationInsights__ConnectionString: <base64>
```

### **2. Injeção nos Pods**

Cada deployment recebe as variáveis:

```yaml
env:
- name: ApplicationInsights__InstrumentationKey
  valueFrom:
    secretKeyRef:
      name: appinsights-secrets
      key: ApplicationInsights__InstrumentationKey
- name: APPLICATIONINSIGHTS_CONNECTION_STRING
  valueFrom:
    secretKeyRef:
      name: appinsights-secrets
      key: ApplicationInsights__ConnectionString
```

---

## ?? **Configuração no Código .NET**

### **1. Instalar o NuGet Package**

Cada projeto deve ter:

```xml
<PackageReference Include="Microsoft.ApplicationInsights.AspNetCore" Version="2.22.0" />
```

### **2. Configurar no Program.cs**

```csharp
// Program.cs
var builder = WebApplication.CreateBuilder(args);

// Adicionar Application Insights
builder.Services.AddApplicationInsightsTelemetry(options =>
{
    options.ConnectionString = builder.Configuration["ApplicationInsights:ConnectionString"];
    options.EnableAdaptiveSampling = true; // Reduz custos em alta escala
    options.EnableDependencyTrackingTelemetryModule = true;
    options.EnableRequestTrackingTelemetryModule = true;
});

// ... resto da configuração
```

### **3. Configurar appsettings.json (Opcional)**

```json
{
  "ApplicationInsights": {
    "ConnectionString": "",
    "LogLevel": {
      "Default": "Information"
    }
  },
  "Logging": {
    "ApplicationInsights": {
      "LogLevel": {
        "Default": "Information",
        "Microsoft": "Warning"
      }
    }
  }
}
```

**Nota:** A connection string vem do secret no Kubernetes, não precisa estar hardcoded.

---

## ?? **Métricas Disponíveis**

### **Automáticas (Zero Config):**

| Métrica | Descrição |
|---------|-----------|
| **Requests** | Todas as requisições HTTP (endpoint, status code, duração) |
| **Dependencies** | Chamadas SQL, Service Bus, HTTP externas |
| **Exceptions** | Exceções não tratadas e falhas |
| **Performance Counters** | CPU, memória, threads |
| **Availability** | Testes de disponibilidade (web tests) |

### **Custom Metrics (Exemplo):**

```csharp
using Microsoft.ApplicationInsights;
using Microsoft.ApplicationInsights.DataContracts;

public class SaleService
{
    private readonly TelemetryClient _telemetry;
    
    public SaleService(TelemetryClient telemetry)
    {
        _telemetry = telemetry;
    }
    
    public async Task<Sale> CreateSale(SaleDto dto)
    {
        // Track custom event
        _telemetry.TrackEvent("SaleCreated", new Dictionary<string, string>
        {
            { "GameId", dto.GameId.ToString() },
            { "Amount", dto.TotalAmount.ToString() }
        });
        
        // Track custom metric
        _telemetry.TrackMetric("SaleAmount", dto.TotalAmount);
        
        // Track dependency (manual)
        using var operation = _telemetry.StartOperation<DependencyTelemetry>("ProcessPayment");
        try
        {
            // Chamar serviço de pagamento
            await CallPaymentService();
            operation.Telemetry.Success = true;
        }
        catch (Exception ex)
        {
            operation.Telemetry.Success = false;
            _telemetry.TrackException(ex);
            throw;
        }
    }
}
```

---

## ?? **Distributed Tracing**

O Application Insights correlaciona automaticamente todas as chamadas:

```
Request: POST /api/sales (FCG)
  ?? Dependency: SQL Query (FCG ? SQL Server)
  ?? Dependency: HTTP GET /api/games/1 (FCG ? Games)
  ?   ?? Dependency: SQL Query (Games ? SQL Server)
  ?? Dependency: ServiceBus Send (FCG ? Service Bus)
      ?? Request: ProcessSale (Payments)
          ?? Dependency: SQL Query (Payments ? SQL Server)
          ?? Dependency: ServiceBus Send (Payments ? Service Bus)
```

Cada operação tem um **Operation ID** único que permite rastrear toda a cadeia.

---

## ?? **Visualizações no Portal**

### **1. Live Metrics (Tempo Real)**

Acesse: Portal ? Application Insights ? Live Metrics

- Requisições por segundo
- Tempo de resposta médio
- Falhas em tempo real
- Servidores online (pods)
- Exceções ao vivo

### **2. Application Map**

Acesse: Portal ? Application Insights ? Application Map

Visualiza a arquitetura automaticamente:
- Dependências entre serviços
- Taxa de falha por componente
- Latência de cada hop
- Health status

### **3. Performance**

Acesse: Portal ? Application Insights ? Performance

- Top 10 operações mais lentas
- Distribuição de tempos de resposta
- Análise de dependências lentas
- Drill-down em requisições específicas

### **4. Failures**

Acesse: Portal ? Application Insights ? Failures

- Taxa de falha ao longo do tempo
- Top exceptions
- Stack traces
- Operações afetadas

### **5. Logs (Kusto Query Language)**

Acesse: Portal ? Application Insights ? Logs

Exemplo de queries:

```kusto
// Todas as requisições com erro nos últimos 30 minutos
requests
| where timestamp > ago(30m)
| where success == false
| project timestamp, name, resultCode, duration

// Dependencies SQL mais lentas
dependencies
| where type == "SQL"
| where duration > 1000  // > 1 segundo
| summarize count(), avg(duration) by name
| order by avg_duration desc

// Exceptions por tipo
exceptions
| summarize count() by type, outerMessage
| order by count_ desc

// Custom events (vendas)
customEvents
| where name == "SaleCreated"
| extend GameId = tostring(customDimensions.GameId)
| summarize TotalSales = count() by GameId
```

---

## ?? **Alertas (Opcional)**

### **Criar Alerta de Taxa de Erro Alta:**

```bash
az monitor metrics alert create \
  --name HighErrorRate \
  --resource-group FCG-Infra \
  --scopes /subscriptions/.../components/fcg-appinsights \
  --condition "avg requests/failed > 10" \
  --window-size 5m \
  --evaluation-frequency 1m \
  --action email me@example.com
```

### **Criar Alerta de Latência Alta:**

```bash
az monitor metrics alert create \
  --name HighLatency \
  --resource-group FCG-Infra \
  --scopes /subscriptions/.../components/fcg-appinsights \
  --condition "avg requests/duration > 3000" \
  --window-size 5m
```

---

## ?? **Custos**

Application Insights usa modelo **pay-as-you-go**:

| Volume de Dados | Custo |
|-----------------|-------|
| Primeiros 5GB/mês | **Gratuito** |
| Acima de 5GB | $2.30/GB |

**Dicas para reduzir custos:**
- Habilitar **Adaptive Sampling** (já configurado)
- Filtrar logs verbosos
- Não logar dados sensíveis

**Estimativa para este projeto:**
- Tráfego baixo/médio: **$0** (dentro do free tier)
- Tráfego alto: ~$10-20/mês

---

## ?? **Testar APM**

### **1. Gerar tráfego:**

```bash
# Requisições ao FCG
for i in {1..100}; do curl http://<FCG-IP>/api/clients; done

# Criar vendas (gera tracing completo)
curl -X POST http://<FCG-IP>/api/sales \
  -H "Content-Type: application/json" \
  -d '{"clientId": 1, "gameId": 1, "quantity": 1}'
```

### **2. Ver no Live Metrics:**

Abra o portal e vá para Live Metrics. Você verá:
- ? Requisições aparecendo em tempo real
- ? Pods reportando telemetria
- ? Dependências SQL/Service Bus

### **3. Analisar Performance:**

Após alguns minutos, vá para Performance e analise:
- Tempo médio de resposta
- Operações mais lentas
- Bottlenecks (SQL? Service Bus?)

---

## ?? **Queries Úteis (KQL)**

### **Dashboard de SLA:**

```kusto
requests
| where timestamp > ago(1h)
| summarize 
    TotalRequests = count(),
    SuccessfulRequests = countif(success == true),
    AvgDuration = avg(duration),
    P95Duration = percentile(duration, 95),
    P99Duration = percentile(duration, 99)
| extend SLA = (SuccessfulRequests * 100.0) / TotalRequests
```

### **Top 10 Operações mais Chamadas:**

```kusto
requests
| where timestamp > ago(24h)
| summarize Count = count(), AvgDuration = avg(duration) by name
| top 10 by Count desc
```

### **Análise de Falhas por Hora:**

```kusto
requests
| where success == false
| where timestamp > ago(24h)
| summarize Failures = count() by bin(timestamp, 1h)
| render timechart
```

---

## ? **Checklist de Implementação**

- [x] Application Insights criado no Azure
- [x] Secret configurado no Kubernetes
- [x] Variáveis de ambiente injetadas nos pods
- [ ] NuGet package instalado nos projetos .NET
- [ ] `AddApplicationInsightsTelemetry()` adicionado no Program.cs
- [ ] Rebuild e push das imagens Docker
- [ ] Redeploy dos pods
- [ ] Validar telemetria no portal

---

## ?? **Próximos Passos**

1. **Adicionar o NuGet nos projetos:**
```bash
cd FCG/src/FCG.Presentation
dotnet add package Microsoft.ApplicationInsights.AspNetCore

cd ../../../Games/src/FCG.Games.Presentation
dotnet add package Microsoft.ApplicationInsights.AspNetCore

cd ../../../Payments/src/FCG.Payments.Presentation
dotnet add package Microsoft.ApplicationInsights.AspNetCore
```

2. **Atualizar Program.cs** (conforme exemplo acima)

3. **Rebuild e push:**
```bash
docker build -t dtpontes/fcgpresentation:latest ...
docker push ...
```

4. **Redeploy:**
```bash
kubectl rollout restart deployment -n fcg-tutorial
```

---

## ?? **Referências**

- [Application Insights Overview](https://learn.microsoft.com/en-us/azure/azure-monitor/app/app-insights-overview)
- [.NET Application Insights](https://learn.microsoft.com/en-us/azure/azure-monitor/app/asp-net-core)
- [Kusto Query Language (KQL)](https://learn.microsoft.com/en-us/azure/data-explorer/kusto/query/)
- [Application Insights Pricing](https://azure.microsoft.com/en-us/pricing/details/monitor/)

---

**Com Application Insights, você tem observabilidade completa da sua arquitetura de microsserviços!** ????
