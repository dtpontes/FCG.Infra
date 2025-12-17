# ??? Bancos de Dados Independentes

Cada microsserviço usa seu próprio banco de dados isolado no mesmo servidor SQL.

---

## ?? **Estrutura de Bancos de Dados:**

```
SQL Server (Pod: sqlserver)
??? fcg              ? FCG Service
??? fcg-games-dev    ? Games Service
??? fcg-payments-dev ? Payments Service
```

---

## ? **Configuração:**

### **1. SQL Server com InitContainer**

O pod do SQL Server tem um **initContainer** que:
1. Aguarda o SQL Server iniciar (40 segundos)
2. Executa o script `init-databases.sql`
3. Cria os 3 bancos automaticamente

**Arquivo:** `k8s-tutorial/sqlserver.yaml`

### **2. ConfigMap com Script SQL**

Define o script SQL que cria os bancos.

**Arquivo:** `k8s-tutorial/sqlserver-init-configmap.yaml`

### **3. Connection Strings por Serviço**

Cada deployment aponta para seu banco específico:

| Serviço | Connection String |
|---------|------------------|
| **FCG** | `Server=sqlserver;Database=fcg;...` |
| **Games** | `Server=sqlserver;Database=fcg-games-dev;...` |
| **Payments** | `Server=sqlserver;Database=fcg-payments-dev;...` |

---

## ?? **Deploy:**

```cmd
cd FCG.Infra
deploy-simples.bat
```

O script automaticamente:
1. ? Cria o namespace
2. ? Aplica o ConfigMap
3. ? Cria o SQL Server
4. ? InitContainer cria os 3 bancos
5. ? Apps iniciam e aplicam suas migrations

---

## ?? **Verificar Bancos Criados:**

```cmd
# Listar bancos de dados
kubectl exec -n fcg-tutorial deployment/sqlserver -- /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "Password123!" -Q "SELECT name FROM sys.databases WHERE name IN ('fcg', 'fcg-games-dev', 'fcg-payments-dev')"
```

**Output esperado:**
```
fcg
fcg-games-dev
fcg-payments-dev
```

---

## ?? **Ver logs do InitContainer:**

```cmd
kubectl logs -n fcg-tutorial -l app=sqlserver -c init-databases
```

**Output esperado:**
```
Waiting for SQL Server to start...
Creating databases...
Database fcg created successfully
Database fcg-games-dev created successfully
Database fcg-payments-dev created successfully
=== All databases initialized successfully ===
Database initialization completed!
```

---

## ?? **Vantagens:**

? **Isolamento**: Cada serviço tem suas próprias tabelas  
? **Migrations Independentes**: Cada serviço gerencia suas migrations  
? **Sem Conflitos**: Tabelas com mesmo nome em diferentes serviços não colidem  
? **Segurança**: Um serviço não acessa dados de outro  

---

## ?? **Testar Conexão Individual:**

```cmd
# FCG
kubectl exec -n fcg-tutorial deployment/fcg-app -- dotnet --version

# Games
kubectl exec -n fcg-tutorial deployment/games-app -- dotnet --version

# Payments
kubectl exec -n fcg-tutorial deployment/payments-app -- dotnet --version
```

---

## ?? **Estrutura de Tabelas por Banco:**

### **fcg:**
- AspNetUsers
- AspNetRoles
- Client
- Sale
- (tabelas do Identity)

### **fcg-games-dev:**
- Game
- Stock
- Sale
- (tabelas do Identity)

### **fcg-payments-dev:**
- Payment
- Sale
- (tabelas do Identity)

---

## ??? **Resetar Bancos:**

```cmd
# Deletar SQL Server (apaga todos os bancos)
kubectl delete pod -l app=sqlserver -n fcg-tutorial

# Aguardar recriar (bancos são recriados vazios)
kubectl get pods -n fcg-tutorial -w

# Restart dos apps para reaplicar migrations
kubectl rollout restart deployment/fcg-app -n fcg-tutorial
kubectl rollout restart deployment/games-app -n fcg-tutorial
kubectl rollout restart deployment/payments-app -n fcg-tutorial
```

---

## ? **Status:**

- ? ConfigMap criado
- ? SQL Server com initContainer
- ? Connection strings configuradas
- ? Scripts de deploy atualizados

**Tudo pronto para deploy!** ??
