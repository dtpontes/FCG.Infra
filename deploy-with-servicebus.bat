@echo off
echo ==========================================
echo Deploy Completo - FCG com Service Bus
echo ==========================================
echo.
echo Este script vai:
echo 1. Criar Resource Group
echo 2. Criar Azure Service Bus + Filas
echo 3. Criar Cluster AKS
echo 4. Deploy das aplicacoes com Service Bus
echo 5. Configurar Auto Scaling
echo.
set /p confirm="Deseja continuar? (S/N): "
if /i not "%confirm%"=="S" exit /b 0

REM ========================================
REM CONFIGURACOES
REM ========================================
set RESOURCE_GROUP=FCG-Infra
set CLUSTER_NAME=FCG-Cluster
set LOCATION=eastus
set NODE_COUNT=1
set SERVICE_BUS_NAMESPACE=fcg-games-servicebus
set SALES_QUEUE=sale-processing-queue
set PAYMENT_QUEUE=payment-processing-queue
set PAYMENT_RESPONSE_QUEUE=response-payment-processing-queue
set APP_INSIGHTS_NAME=fcg-appinsights

echo.
echo ==========================================
echo Passo 1: Login no Azure
echo ==========================================
call az login
if %errorlevel% neq 0 (
    echo [ERRO] Falha no login
    pause
    exit /b %errorlevel%
)

echo.
echo ==========================================
echo Passo 2: Criando Resource Group
echo ==========================================
call az group create --name %RESOURCE_GROUP% --location %LOCATION%

echo.
echo ==========================================
echo Passo 3: Criando Service Bus
echo ==========================================
echo Criando namespace: %SERVICE_BUS_NAMESPACE%
call az servicebus namespace create ^
    --resource-group %RESOURCE_GROUP% ^
    --name %SERVICE_BUS_NAMESPACE% ^
    --location %LOCATION% ^
    --sku Standard

echo Criando fila: %SALES_QUEUE%
call az servicebus queue create ^
    --resource-group %RESOURCE_GROUP% ^
    --namespace-name %SERVICE_BUS_NAMESPACE% ^
    --name %SALES_QUEUE%

echo Criando fila: %PAYMENT_QUEUE%
call az servicebus queue create ^
    --resource-group %RESOURCE_GROUP% ^
    --namespace-name %SERVICE_BUS_NAMESPACE% ^
    --name %PAYMENT_QUEUE%

echo Criando fila: %PAYMENT_RESPONSE_QUEUE%
call az servicebus queue create ^
    --resource-group %RESOURCE_GROUP% ^
    --namespace-name %SERVICE_BUS_NAMESPACE% ^
    --name %PAYMENT_RESPONSE_QUEUE%

echo.
echo Obtendo Connection String...
for /f "tokens=*" %%i in ('az servicebus namespace authorization-rule keys list --resource-group %RESOURCE_GROUP% --namespace-name %SERVICE_BUS_NAMESPACE% --name RootManageSharedAccessKey --query primaryConnectionString -o tsv') do set SERVICE_BUS_CONN=%%i

echo Connection String obtida!

echo.
echo ==========================================
echo Passo 4: Registrando Providers
echo ==========================================
call az provider register --namespace Microsoft.ContainerService
call az provider register --namespace Microsoft.Compute
call az provider register --namespace Microsoft.Network
call az provider register --namespace microsoft.insights
call az provider register --namespace microsoft.operationalinsights
echo Aguardando providers (90 segundos)...
timeout /t 90 /nobreak

echo.
echo ==========================================
echo Passo 4.1: Criando Application Insights
echo ==========================================
echo Criando workspace do Application Insights...
call az monitor app-insights component create ^
    --app %APP_INSIGHTS_NAME% ^
    --location %LOCATION% ^
    --resource-group %RESOURCE_GROUP% ^
    --kind web

echo.
echo Obtendo Instrumentation Key...
for /f "tokens=*" %%i in ('az monitor app-insights component show --app %APP_INSIGHTS_NAME% --resource-group %RESOURCE_GROUP% --query instrumentationKey -o tsv') do set APPINSIGHTS_KEY=%%i

echo.
echo Obtendo Connection String do Application Insights...
for /f "tokens=*" %%i in ('az monitor app-insights component show --app %APP_INSIGHTS_NAME% --resource-group %RESOURCE_GROUP% --query connectionString -o tsv') do set APPINSIGHTS_CONN=%%i

echo Application Insights criado com sucesso!

echo.
echo ==========================================
echo Passo 5: Criando Cluster AKS
echo ==========================================
echo.
echo Obtendo Subscription ID...
for /f "tokens=*" %%i in ('az account show --query id -o tsv') do set SUBSCRIPTION_ID=%%i

call az aks create ^
    --resource-group %RESOURCE_GROUP% ^
    --name %CLUSTER_NAME% ^
    --node-count %NODE_COUNT% ^
    --node-vm-size Standard_D2s_v3 ^
    --no-ssh-key

echo.
echo ==========================================
echo Passo 6: Conectando kubectl
echo ==========================================
call az aks get-credentials --resource-group %RESOURCE_GROUP% --name %CLUSTER_NAME% --overwrite-existing
kubectl get nodes

echo.
echo ==========================================
echo Passo 7: Deploy das Aplicacoes
echo ==========================================
kubectl apply -f k8s-tutorial/namespace.yaml --validate=false
timeout /t 5 /nobreak

echo.
echo ==========================================
echo Passo 8: Criando Kubernetes Secrets
echo ==========================================
kubectl create secret generic servicebus-secrets ^
    --from-literal=ServiceBus__ConnectionString="%SERVICE_BUS_CONN%" ^
    --from-literal=ServiceBus__SalesQueueName="%SALES_QUEUE%" ^
    --from-literal=ServiceBus__PaymentQueueName="%PAYMENT_QUEUE%" ^
    --from-literal=ServiceBus__PaymentResponseQueueName="%PAYMENT_RESPONSE_QUEUE%" ^
    --from-literal=ServiceBus__MaxConcurrentCalls="5" ^
    --from-literal=ServiceBus__MessageTimeoutSeconds="300" ^
    --namespace=fcg-tutorial ^
    --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic appinsights-secrets ^
    --from-literal=ApplicationInsights__InstrumentationKey="%APPINSIGHTS_KEY%" ^
    --from-literal=ApplicationInsights__ConnectionString="%APPINSIGHTS_CONN%" ^
    --namespace=fcg-tutorial ^
    --dry-run=client -o yaml | kubectl apply -f -

echo.
echo ==========================================
echo Passo 9: Deploy dos Serviços
echo ==========================================
kubectl apply -f k8s-tutorial/sqlserver.yaml --validate=false

echo Aguardando SQL Server ficar pronto...
kubectl wait --namespace=fcg-tutorial --for=condition=ready pod -l app=sqlserver --timeout=120s

echo.
echo Criando bancos de dados...
kubectl apply -f k8s-tutorial/sqlserver-init-job.yaml --validate=false
kubectl wait --namespace=fcg-tutorial --for=condition=complete job/sqlserver-init-job --timeout=180s

echo.
echo Aplicando servicos com Application Insights...
kubectl apply -f k8s-tutorial/fcg-with-apm.yaml --validate=false
kubectl apply -f k8s-tutorial/games-with-apm.yaml --validate=false
kubectl apply -f k8s-tutorial/payments-with-apm.yaml --validate=false

echo.
echo ==========================================
echo Passo 10: Configurando LoadBalancers
echo ==========================================
kubectl patch service fcg-service -n fcg-tutorial -p "{\"spec\":{\"type\":\"LoadBalancer\"}}"
kubectl patch service games-service -n fcg-tutorial -p "{\"spec\":{\"type\":\"LoadBalancer\"}}"
kubectl patch service payments-service -n fcg-tutorial -p "{\"spec\":{\"type\":\"LoadBalancer\"}}"

echo.
echo ==========================================
echo Passo 11: Atualizando Imagens
echo ==========================================
kubectl set image deployment/fcg-app fcg-app=dtpontes/fcgpresentation:latest -n fcg-tutorial
kubectl set image deployment/games-app games-app=dtpontes/fcggamespresentation:latest -n fcg-tutorial
kubectl set image deployment/payments-app payments-app=dtpontes/fcgpaymentspresentation:latest -n fcg-tutorial

echo.
echo ==========================================
echo Passo 12: Aplicando HPA
echo ==========================================
kubectl apply -f k8s-tutorial/fcg-hpa.yaml
kubectl apply -f k8s-tutorial/games-hpa.yaml
kubectl apply -f k8s-tutorial/payments-hpa.yaml

echo.
echo ==========================================
echo Passo 13: Aguardando Pods
echo ==========================================
kubectl wait --namespace=fcg-tutorial --for=condition=ready pod -l app=sqlserver --timeout=180s
kubectl wait --namespace=fcg-tutorial --for=condition=ready pod -l app=fcg-app --timeout=180s
kubectl wait --namespace=fcg-tutorial --for=condition=ready pod -l app=games-app --timeout=180s
kubectl wait --namespace=fcg-tutorial --for=condition=ready pod -l app=payments-app --timeout=180s

timeout /t 30 /nobreak

echo.
echo ==========================================
echo DEPLOY CONCLUIDO COM SERVICE BUS + APM!
echo ==========================================
kubectl get services -n fcg-tutorial
echo.
echo ==========================================
echo Service Bus Configurado:
echo ==========================================
echo Namespace: %SERVICE_BUS_NAMESPACE%
echo Filas: %SALES_QUEUE%, %PAYMENT_QUEUE%, %PAYMENT_RESPONSE_QUEUE%
echo.
echo ==========================================
echo Application Insights Configurado:
echo ==========================================
echo Nome: %APP_INSIGHTS_NAME%
echo Instrumentation Key: %APPINSIGHTS_KEY%
echo.
echo Portal do Application Insights:
echo https://portal.azure.com/#@/resource/subscriptions/%SUBSCRIPTION_ID%/resourceGroups/%RESOURCE_GROUP%/providers/microsoft.insights/components/%APP_INSIGHTS_NAME%/overview
echo.
echo Link Direto (copie e cole no navegador):
echo https://portal.azure.com/#view/AppInsightsExtension/ComponentDetailsBladeV2/ComponentId/%%2Fsubscriptions%%2F%SUBSCRIPTION_ID%%%2FresourceGroups%%2F%RESOURCE_GROUP%%%2Fproviders%%2Fmicrosoft.insights%%2Fcomponents%%2F%APP_INSIGHTS_NAME%
echo.
echo Para visualizar metricas em tempo real:
echo - Acesse o portal acima
echo - Live Metrics: Metricas em tempo real
echo - Application Map: Visualizacao da arquitetura
echo - Performance: Analise de performance
echo - Failures: Analise de falhas
echo - Logs: Query logs com KQL
echo.
echo Para deletar tudo:
echo az group delete --name %RESOURCE_GROUP% --yes --no-wait
echo.
pause
