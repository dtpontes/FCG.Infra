# ?? FCG Infrastructure - Deploy Completo

Infraestrutura como Código (IaC) para deploy de microsserviços FCG no Azure Kubernetes Service (AKS) com Application Performance Monitoring.

---

## ?? **Estrutura do Projeto**

```
FCG.Infra/
??? ?? deploy-with-servicebus.bat    # Script principal de deploy
??? ?? get-appinsights-link.bat      # Obter link do Application Insights
?
??? ?? k8s-tutorial/                  # Manifestos Kubernetes
?   ??? namespace.yaml                # Namespace fcg-tutorial
?   ??? sqlserver.yaml                # SQL Server deployment
?   ??? sqlserver-init-job.yaml       # Job para criar databases
?   ?
?   ??? fcg-with-apm.yaml             # FCG Service + APM
?   ??? games-with-apm.yaml           # Games Service + APM
?   ??? payments-with-apm.yaml        # Payments Service + APM
?   ?
?   ??? fcg-hpa.yaml                  # Auto Scaling - FCG
?   ??? games-hpa.yaml                # Auto Scaling - Games
?   ??? payments-hpa.yaml             # Auto Scaling - Payments
?
??? ?? Documentação/
    ??? APM-README.md                 # Guia Application Insights
    ??? apresentacao_fiap.md          # Apresentação técnica completa
    ??? SERVICEBUS-README.md          # Guia Service Bus
    ??? TROUBLESHOOTING-APPINSIGHTS.md # Troubleshooting APM
```

---

## ?? **Deploy Rápido**

### **1. Pré-requisitos**

- ? Azure CLI instalado
- ? kubectl instalado
- ? Conta Azure ativa
- ? Imagens Docker no DockerHub:
  - `dtpontes/fcgpresentation:latest`
  - `dtpontes/fcggamespresentation:latest`
  - `dtpontes/fcgpaymentspresentation:latest`

### **2. Executar Deploy**

```cmd
cd FCG.Infra
deploy-with-servicebus.bat
```

**Tempo estimado:** 20-25 minutos

---

## ?? **O que será criado?**

| Recurso | Tipo | Finalidade |
|---------|------|-----------|
| **FCG-Infra** | Resource Group | Container lógico |
| **fcg-games-servicebus** | Service Bus | Mensageria (3 filas) |
| **fcg-appinsights** | Application Insights | APM/Observabilidade |
| **FCG-Cluster** | AKS | Cluster Kubernetes (1 nó) |
| **fcg-tutorial** | Namespace | Isolamento no K8s |
| **sqlserver** | Pod | SQL Server 2022 (3 databases) |
| **fcg-app** | Deployment | API Gateway/BFF (1-5 pods) |
| **games-app** | Deployment | Games Service (1-10 pods) |
| **payments-app** | Deployment | Payments Service (2-8 pods) |
| **3x LoadBalancer** | Service | IPs públicos para APIs |
| **3x HPA** | Auto Scaling | Escalabilidade automática |

---

## ?? **Passo a Passo do Deploy**

### **Passo 1: Azure Resources**
1. Login no Azure
2. Criar Resource Group (FCG-Infra)
3. Criar Service Bus + 3 filas
4. Registrar providers (ContainerService, Insights, etc.)
5. Criar Application Insights

### **Passo 2: Kubernetes Cluster**
6. Criar AKS Cluster (1 nó Standard_D2s_v3)
7. Conectar kubectl ao cluster

### **Passo 3: Deploy Aplicações**
8. Criar namespace `fcg-tutorial`
9. Criar Secrets (Service Bus + Application Insights)
10. Deploy SQL Server + Job de inicialização
11. Deploy dos 3 microsserviços (com APM)
12. Configurar LoadBalancers (IPs públicos)
13. Atualizar imagens do DockerHub
14. Aplicar HPA (Auto Scaling)

---

## ?? **Auto Scaling Configurado**

| Serviço | Min Pods | Max Pods | Trigger |
|---------|----------|----------|---------|
| **FCG** | 1 | 5 | CPU > 70% ou MEM > 80% |
| **Games** | 1 | 10 | CPU > 70% ou MEM > 80% |
| **Payments** | 2 | 8 | CPU > 70% ou MEM > 80% |

---

## ?? **Application Performance Monitoring**

### **Acessar Application Insights:**

Após o deploy, execute:
```cmd
get-appinsights-link.bat
```

Ou acesse diretamente:
```
https://portal.azure.com ? Pesquisar "fcg-appinsights"
```

### **Métricas Disponíveis:**
- ? **Live Metrics**: Tempo real
- ? **Application Map**: Arquitetura visual
- ? **Performance**: Análise de latência
- ? **Failures**: Exceções e stack traces
- ? **Logs**: Query com KQL

Veja detalhes em: [`APM-README.md`](./APM-README.md)

---

## ?? **Acessar os Serviços**

Após o deploy, obtenha os IPs públicos:

```cmd
kubectl get services -n fcg-tutorial
```

**Swaggers:**
- FCG: `http://<FCG-EXTERNAL-IP>/swagger`
- Games: `http://<GAMES-EXTERNAL-IP>/swagger`
- Payments: `http://<PAYMENTS-EXTERNAL-IP>/swagger`

---

## ?? **Custos Estimados (24/7)**

| Recurso | Custo Mensal |
|---------|--------------|
| AKS (1 nó D2s_v3) | ~$70 |
| Service Bus Standard | ~$10 |
| Application Insights | $0-20 (5GB free) |
| Load Balancers (3x) | ~$15 |
| IPs Públicos (3x) | ~$10 |
| **TOTAL** | **~$105-125/mês** |

---

## ??? **Limpeza Completa**

Para deletar **TODOS** os recursos:

```cmd
az group delete --name FCG-Infra --yes --no-wait
```

Isso remove:
- ? Cluster AKS
- ? Service Bus + filas
- ? Application Insights
- ? Load Balancers
- ? IPs públicos
- ? VMs e discos

---

## ?? **Testar a Solução**

### **1. Verificar Pods:**
```cmd
kubectl get pods -n fcg-tutorial
```

### **2. Ver Logs:**
```cmd
kubectl logs -l app=games-app -n fcg-tutorial -f
```

### **3. Testar API:**
```cmd
curl http://<GAMES-IP>/api/games
```

### **4. Monitorar Auto Scaling:**
```cmd
kubectl get hpa -n fcg-tutorial --watch
```

---

## ?? **Documentação Completa**

- **[APM-README.md](./APM-README.md)**: Guia completo de Application Insights
- **[apresentacao_fiap.md](./apresentacao_fiap.md)**: Apresentação técnica para FIAP
- **[SERVICEBUS-README.md](./SERVICEBUS-README.md)**: Configuração do Service Bus
- **[TROUBLESHOOTING-APPINSIGHTS.md](./TROUBLESHOOTING-APPINSIGHTS.md)**: Resolver problemas de APM

---

## ?? **Para Apresentação FIAP**

Use o arquivo [`apresentacao_fiap.md`](./apresentacao_fiap.md) que contém:
- ? Visão geral da arquitetura
- ? Conceitos fundamentais (Kubernetes, HPA, APM)
- ? Explicação detalhada de cada passo
- ? Diagramas e estimativa de custos
- ? Boas práticas implementadas

---

## ?? **Repositórios GitHub**

- **FCG Service**: https://github.com/dtpontes/FCG
- **Games Service**: https://github.com/dtpontes/FCG.Games
- **Payments Service**: https://github.com/dtpontes/FCG.Payments
- **Infraestrutura**: https://github.com/dtpontes/FCG.Infra

---

## ? **Arquitetura Implementada**

```
???????????????????????????????????????????????
?         Azure Resource Group (FCG-Infra)    ?
?                                             ?
?  ????????????????????????????????????????? ?
?  ?   Azure Service Bus                   ? ?
?  ?   • sale-processing-queue             ? ?
?  ?   • payment-processing-queue          ? ?
?  ?   • response-payment-processing-queue ? ?
?  ????????????????????????????????????????? ?
?                                             ?
?  ????????????????????????????????????????? ?
?  ?   Application Insights (APM)          ? ?
?  ?   • Live Metrics                      ? ?
?  ?   • Distributed Tracing               ? ?
?  ?   • Performance Analysis              ? ?
?  ????????????????????????????????????????? ?
?                                             ?
?  ????????????????????????????????????????? ?
?  ?   AKS Cluster (FCG-Cluster)           ? ?
?  ?                                       ? ?
?  ?   ???????????????????????????????    ? ?
?  ?   ? Namespace: fcg-tutorial     ?    ? ?
?  ?   ?                             ?    ? ?
?  ?   ? • SQL Server (3 databases)  ?    ? ?
?  ?   ? • FCG Service (HPA 1-5)     ?    ? ?
?  ?   ? • Games Service (HPA 1-10)  ?    ? ?
?  ?   ? • Payments Service (HPA 2-8)?    ? ?
?  ?   ?                             ?    ? ?
?  ?   ? LoadBalancers:              ?    ? ?
?  ?   ? • FCG (IP público)          ?    ? ?
?  ?   ? • Games (IP público)        ?    ? ?
?  ?   ? • Payments (IP público)     ?    ? ?
?  ?   ???????????????????????????????    ? ?
?  ????????????????????????????????????????? ?
???????????????????????????????????????????????
```

---

## ?? **Boas Práticas Implementadas**

- ? **Infrastructure as Code (IaC)**: Scripts automatizados
- ? **Database per Service**: Isolamento de dados
- ? **Auto Scaling (HPA)**: Escalabilidade automática
- ? **Health Checks**: Readiness/Liveness probes
- ? **Secrets Management**: Credenciais via K8s Secrets
- ? **Observability**: Application Insights para APM
- ? **Messaging**: Comunicação assíncrona via Service Bus
- ? **Zero Downtime**: Rolling updates
- ? **Resource Limits**: Controle de CPU/memória

---

**Desenvolvido por:** Daniel Pontes  
**Para:** Apresentação FIAP - Microsserviços e Kubernetes  
**Repositório:** https://github.com/dtpontes/FCG.Infra
