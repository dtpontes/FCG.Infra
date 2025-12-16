@echo off
echo ==========================================
echo Deploy FCG no Azure Kubernetes (AKS)
echo ==========================================
echo.
echo Este script vai:
echo 1. Criar um Resource Group no Azure
echo 2. Criar um Cluster AKS (Kubernetes gerenciado)
echo 3. Conectar seu kubectl ao Azure
echo 4. Fazer deploy das aplicacoes FCG, Games e Payments
echo.
pause

REM ========================================
REM CONFIGURACOES (Edite aqui se quiser)
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
echo Criando grupo de recursos: %RESOURCE_GROUP%
call az group create --name %RESOURCE_GROUP% --location %LOCATION%
if %errorlevel% neq 0 (
    echo [ERRO] Falha ao criar Resource Group
    pause
    exit /b %errorlevel%
)

echo.
echo ==========================================
echo Passo 2.5: Registrando Providers do Azure
echo ==========================================
echo Registrando Microsoft.ContainerService (AKS)...
call az provider register --namespace Microsoft.ContainerService
echo Registrando Microsoft.Compute...
call az provider register --namespace Microsoft.Compute
echo Registrando Microsoft.Network...
call az provider register --namespace Microsoft.Network
echo.
echo Aguardando providers ficarem prontos (isso pode levar 1-2 minutos)...
timeout /t 60 /nobreak

echo.
echo ==========================================
echo Passo 3: Criando Cluster AKS
echo ==========================================
echo ATENCAO: Este passo pode levar de 5 a 10 minutos!
echo Criando cluster: %CLUSTER_NAME% com %NODE_COUNT% nos
echo.
call az aks create ^
    --resource-group %RESOURCE_GROUP% ^
    --name %CLUSTER_NAME% ^
    --node-count %NODE_COUNT% ^
    --node-vm-size Standard_D2s_v3 ^
    --no-ssh-key
    
if %errorlevel% neq 0 (
    echo [ERRO] Falha ao criar o cluster AKS
    pause
    exit /b %errorlevel%
)

echo.
echo ==========================================
echo Passo 4: Conectando kubectl ao AKS
echo ==========================================
call az aks get-credentials --resource-group %RESOURCE_GROUP% --name %CLUSTER_NAME% --overwrite-existing
if %errorlevel% neq 0 (
    echo [ERRO] Falha ao conectar ao cluster
    pause
    exit /b %errorlevel%
)

echo.
echo Verificando conexao com o cluster...
kubectl get nodes
if %errorlevel% neq 0 (
    echo [ERRO] Nao foi possivel conectar ao cluster
    pause
    exit /b %errorlevel%
)

echo.
echo ==========================================
echo Passo 5: Deploy das Aplicacoes no AKS
echo ==========================================
echo Aplicando configuracoes do Kubernetes (modo Azure com LoadBalancer)...
kubectl apply -k k8s-tutorial/azure
if %errorlevel% neq 0 (
    echo [ERRO] Falha ao aplicar as configuracoes
    pause
    exit /b %errorlevel%
)

echo.
echo ==========================================
echo Passo 6: Aguardando os Pods ficarem prontos
echo ==========================================
echo Aguardando SQL Server...
kubectl wait --namespace=fcg-tutorial --for=condition=ready pod -l app=sqlserver --timeout=180s

echo.
echo Aguardando FCG App...
kubectl wait --namespace=fcg-tutorial --for=condition=ready pod -l app=fcg-app --timeout=180s

echo.
echo Aguardando Games App...
kubectl wait --namespace=fcg-tutorial --for=condition=ready pod -l app=games-app --timeout=180s

echo.
echo Aguardando Payments App...
kubectl wait --namespace=fcg-tutorial --for=condition=ready pod -l app=payments-app --timeout=180s

echo.
echo ==========================================
echo Passo 7: Aguardando IPs Publicos
echo ==========================================
echo O Azure esta criando Load Balancers publicos para seus servicos...
echo Isso pode levar alguns minutos.
echo.
timeout /t 30 /nobreak

echo.
echo ==========================================
echo DEPLOY CONCLUIDO!
echo ==========================================
echo.
echo Para ver os IPs publicos dos seus servicos, execute:
echo kubectl get services -n fcg-tutorial
echo.
echo Quando a coluna EXTERNAL-IP mostrar um IP (nao ^<pending^>), voce podera acessar:
echo.
echo FCG Swagger:      http://^<EXTERNAL-IP-FCG^>/swagger
echo Games Swagger:    http://^<EXTERNAL-IP-GAMES^>/swagger
echo Payments Swagger: http://^<EXTERNAL-IP-PAYMENTS^>/swagger
echo.
echo Para ver os logs: kubectl logs -l app=fcg-app -n fcg-tutorial
echo Para ver os pods: kubectl get pods -n fcg-tutorial
echo.
echo IMPORTANTE: Lembre-se de deletar os recursos quando nao precisar mais para evitar custos:
echo az group delete --name %RESOURCE_GROUP% --yes --no-wait
echo.
pause