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
timeout /t 60 /nobreak

echo.
echo ==========================================
echo Passo 5: Criando Cluster AKS
echo ==========================================
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
echo Passo 8: Criando Kubernetes Secret
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

echo.
echo ==========================================
echo Passo 9: Deploy dos Serviços
echo ==========================================
kubectl apply -f k8s-tutorial/sqlserver.yaml --validate=false
kubectl apply -f k8s-tutorial/fcg-fixed.yaml --validate=false
kubectl apply -f k8s-tutorial/games.yaml --validate=false
kubectl apply -f k8s-tutorial/payments.yaml --validate=false

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
echo DEPLOY CONCLUIDO COM SERVICE BUS!
echo ==========================================
kubectl get services -n fcg-tutorial
echo.
echo ==========================================
echo Service Bus Configurado:
echo ==========================================
echo Namespace: %SERVICE_BUS_NAMESPACE%
echo Filas: %SALES_QUEUE%, %PAYMENT_QUEUE%, %PAYMENT_RESPONSE_QUEUE%
echo.
echo Para deletar tudo:
echo az group delete --name %RESOURCE_GROUP% --yes --no-wait
echo.
pause
