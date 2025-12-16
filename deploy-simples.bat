@echo off
echo ==========================================
echo Deploy Simples - FCG no Azure AKS
echo ==========================================
echo.
echo Este script vai:
echo 1. Criar Resource Group
echo 2. Criar Cluster AKS
echo 3. Fazer Deploy das 3 aplicacoes
echo 4. Configurar LoadBalancers publicos
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

echo.
echo ==========================================
echo Passo 1: Login no Azure
echo ==========================================
call az login
if %errorlevel% neq 0 (
    echo [ERRO] Falha no login do Azure
    pause
    exit /b %errorlevel%
)

echo.
echo ==========================================
echo Passo 2: Criando Resource Group
echo ==========================================
echo Criando: %RESOURCE_GROUP%
call az group create --name %RESOURCE_GROUP% --location %LOCATION%
if %errorlevel% neq 0 (
    echo [ERRO] Falha ao criar Resource Group
    pause
    exit /b %errorlevel%
)

echo.
echo ==========================================
echo Passo 3: Registrando Providers
echo ==========================================
call az provider register --namespace Microsoft.ContainerService
call az provider register --namespace Microsoft.Compute
call az provider register --namespace Microsoft.Network
echo Aguardando providers (1 minuto)...
timeout /t 60 /nobreak

echo.
echo ==========================================
echo Passo 4: Criando Cluster AKS
echo ==========================================
echo AGUARDE: 5-10 minutos
call az aks create ^
    --resource-group %RESOURCE_GROUP% ^
    --name %CLUSTER_NAME% ^
    --node-count %NODE_COUNT% ^
    --node-vm-size Standard_D2s_v3 ^
    --no-ssh-key
    
if %errorlevel% neq 0 (
    echo [ERRO] Falha ao criar cluster
    pause
    exit /b %errorlevel%
)

echo.
echo ==========================================
echo Passo 5: Conectando kubectl
echo ==========================================
call az aks get-credentials --resource-group %RESOURCE_GROUP% --name %CLUSTER_NAME% --overwrite-existing
kubectl get nodes

echo.
echo ==========================================
echo Passo 6: Deploy das Aplicacoes
echo ==========================================
kubectl apply -f k8s-tutorial/namespace.yaml --validate=false
timeout /t 5 /nobreak

kubectl apply -f k8s-tutorial/sqlserver.yaml --validate=false
kubectl apply -f k8s-tutorial/fcg-fixed.yaml --validate=false
kubectl apply -f k8s-tutorial/games.yaml --validate=false
kubectl apply -f k8s-tutorial/payments.yaml --validate=false

echo.
echo ==========================================
echo Passo 7: Configurando LoadBalancers
echo ==========================================
kubectl patch service fcg-service -n fcg-tutorial -p "{\"spec\":{\"type\":\"LoadBalancer\"}}"
kubectl patch service games-service -n fcg-tutorial -p "{\"spec\":{\"type\":\"LoadBalancer\"}}"
kubectl patch service payments-service -n fcg-tutorial -p "{\"spec\":{\"type\":\"LoadBalancer\"}}"

echo.
echo ==========================================
echo Passo 8: Atualizando Imagens DockerHub
echo ==========================================
kubectl set image deployment/fcg-app fcg-app=dtpontes/fcgpresentation:latest -n fcg-tutorial
kubectl set image deployment/games-app games-app=dtpontes/fcggamespresentation:latest -n fcg-tutorial
kubectl set image deployment/payments-app payments-app=dtpontes/fcgpaymentspresentation:latest -n fcg-tutorial

echo.
echo ==========================================
echo Passo 9: Aguardando Pods
echo ==========================================
kubectl wait --namespace=fcg-tutorial --for=condition=ready pod -l app=sqlserver --timeout=180s
kubectl wait --namespace=fcg-tutorial --for=condition=ready pod -l app=fcg-app --timeout=180s
kubectl wait --namespace=fcg-tutorial --for=condition=ready pod -l app=games-app --timeout=180s
kubectl wait --namespace=fcg-tutorial --for=condition=ready pod -l app=payments-app --timeout=180s

echo.
echo ==========================================
echo Passo 10: Aguardando IPs Publicos
echo ==========================================
timeout /t 30 /nobreak

echo.
echo ==========================================
echo Passo 11: Aplicando Auto Scaling (HPA)
echo ==========================================
kubectl apply -f k8s-tutorial/fcg-hpa.yaml
kubectl apply -f k8s-tutorial/games-hpa.yaml
kubectl apply -f k8s-tutorial/payments-hpa.yaml

echo.
echo ==========================================
echo DEPLOY CONCLUIDO!
echo ==========================================
kubectl get services -n fcg-tutorial
echo.
echo Acesse os servicos:
echo FCG:      http://^<EXTERNAL-IP^>/swagger
echo Games:    http://^<EXTERNAL-IP^>/swagger
echo Payments: http://^<EXTERNAL-IP^>/swagger
echo.
echo ==========================================
echo Auto Scaling Configurado:
echo ==========================================
echo FCG:      1-5 replicas   (CPU: 70%%, MEM: 80%%)
echo Games:    1-10 replicas  (CPU: 70%%, MEM: 80%%)
echo Payments: 2-8 replicas   (CPU: 70%%, MEM: 80%%)
echo.
echo Para monitorar: kubectl get hpa -n fcg-tutorial
echo.
echo Para deletar tudo:
echo az group delete --name %RESOURCE_GROUP% --yes --no-wait
echo.
pause
