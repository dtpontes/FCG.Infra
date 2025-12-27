# ?? Troubleshooting: Application Insights

## Erro: "microsoft.operationalinsights is not registered"

### **Mensagem de Erro:**
```
(Conflict) Failed to register resource provider 'microsoft.operationalinsights'. 
Ensure that microsoft.operationalinsights is registered for this subscription.
```

---

## ? **Solução Automática (Script Atualizado)**

O script `deploy-with-servicebus.bat` foi atualizado para registrar automaticamente os providers necessários:

```cmd
az provider register --namespace microsoft.insights
az provider register --namespace microsoft.operationalinsights
```

**Execute novamente:**
```cmd
cd FCG.Infra
deploy-with-servicebus.bat
```

O script agora aguarda 90 segundos após registrar os providers antes de criar o Application Insights.

---

## ? **Solução Manual (Se ainda falhar)**

### **1. Registrar providers manualmente:**

```cmd
# Registrar providers necessários
az provider register --namespace microsoft.insights
az provider register --namespace microsoft.operationalinsights

# Verificar status (aguarde até aparecer "Registered")
az provider show --namespace microsoft.insights --query "registrationState"
az provider show --namespace microsoft.operationalinsights --query "registrationState"
```

### **2. Aguardar propagação (2-3 minutos):**

```cmd
timeout /t 180
```

### **3. Tentar criar o Application Insights novamente:**

```cmd
az monitor app-insights component create \
  --app fcg-appinsights \
  --location eastus \
  --resource-group FCG-Infra \
  --kind web
```

---

## ?? **Ordem Correta de Execução**

O script agora executa na ordem correta:

1. ? Login no Azure
2. ? Criar Resource Group
3. ? Criar Service Bus
4. ? **Registrar Providers** (incluindo insights e operationalinsights)
5. ? Aguardar 90 segundos
6. ? **Criar Application Insights** (agora funciona!)
7. ? Criar Cluster AKS
8. ? Resto do deploy...

---

## ?? **Verificar se os Providers estão Registrados**

```cmd
# Listar todos os providers relacionados ao Application Insights
az provider list --query "[?namespace=='microsoft.insights' || namespace=='microsoft.operationalinsights'].{Namespace:namespace, State:registrationState}" -o table
```

**Output esperado:**
```
Namespace                        State
-------------------------------  ----------
microsoft.insights               Registered
microsoft.operationalinsights    Registered
```

---

## ?? **Se mesmo assim não funcionar**

### **Problema: Assinatura gratuita/student com limitações**

Algumas assinaturas do Azure (especialmente gratuitas ou para estudantes) podem ter restrições para criar recursos do Application Insights.

### **Alternativa: Deploy sem APM**

Se o Application Insights não for essencial para sua apresentação:

```cmd
cd FCG.Infra
deploy-simples.bat
```

Isso faz o deploy completo **sem** Application Insights, mas ainda com:
- ? Kubernetes (AKS)
- ? Service Bus
- ? Auto Scaling (HPA)
- ? Microsserviços

---

## ?? **Verificar se Application Insights foi criado**

```cmd
# Listar Application Insights no Resource Group
az monitor app-insights component list \
  --resource-group FCG-Infra \
  --query "[].{Name:name, Location:location, InstrumentationKey:instrumentationKey}" \
  -o table

# Ver detalhes
az monitor app-insights component show \
  --app fcg-appinsights \
  --resource-group FCG-Infra
```

---

## ?? **Dica para Apresentação**

Se você não conseguir criar o Application Insights devido a limitações da assinatura:

1. **Use `deploy-simples.bat`** para a demo
2. **Mencione na apresentação** que em produção você usaria Application Insights para:
   - Live Metrics
   - Distributed Tracing
   - Performance Analysis
   - Application Map
3. **Mostre screenshots** do portal do Application Insights (use exemplos da documentação)

Isso demonstra conhecimento mesmo sem ter o recurso ativo! ??

---

## ?? **Comandos Úteis**

```cmd
# Ver todas as extensões instaladas do Azure CLI
az extension list -o table

# Atualizar extensão application-insights
az extension update --name application-insights

# Habilitar instalação automática de extensões
az config set extension.use_dynamic_install=yes_without_prompt

# Permitir versões preview
az config set extension.dynamic_install_allow_preview=true
```

---

## ?? **Referências**

- [Azure Resource Providers](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/resource-providers-and-types)
- [Application Insights Overview](https://learn.microsoft.com/en-us/azure/azure-monitor/app/app-insights-overview)
- [Azure CLI Extension Management](https://learn.microsoft.com/en-us/cli/azure/azure-cli-extensions-overview)

---

**Execute `deploy-with-servicebus.bat` novamente e deve funcionar!** ??
