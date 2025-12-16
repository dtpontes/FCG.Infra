@echo off
echo ==========================================
echo 1. Construindo as imagens Docker...
echo ==========================================
echo [1/3] Construindo FCG Presentation...
docker build -t fcg-presentation:local -f FCG\src\FCG.Presentation\Dockerfile FCG
if %errorlevel% neq 0 (
    echo.
    echo [ERRO] Falha ao construir a imagem FCG.
    pause
    exit /b %errorlevel%
)

echo [2/3] Construindo Games Presentation...
docker build -t games-presentation:local -f Games\src\FCG.Games.Presentation\Dockerfile Games
if %errorlevel% neq 0 (
    echo.
    echo [ERRO] Falha ao construir a imagem Games.
    pause
    exit /b %errorlevel%
)

echo [3/3] Construindo Payments Presentation...
docker build -t payments-presentation:local -f Payments\src\FCG.Payments.Presentation\Dockerfile Payments
if %errorlevel% neq 0 (
    echo.
    echo [ERRO] Falha ao construir a imagem Payments.
    pause
    exit /b %errorlevel%
)

echo.
echo ==========================================
echo 2. Criando Namespace e Aplicando configuracoes...
echo ==========================================
REM Cria o namespace explicitamente para evitar erros de "NotFound"
kubectl create namespace fcg-tutorial --dry-run=client -o yaml | kubectl apply -f -
if %errorlevel% neq 0 (
    echo.
    echo [ERRO] Falha ao criar o namespace.
    pause
    exit /b %errorlevel%
)

kubectl apply -k k8s-tutorial
if %errorlevel% neq 0 (
    echo.
    echo [ERRO] Falha ao aplicar os arquivos YAML.
    pause
    exit /b %errorlevel%
)

echo.
echo ==========================================
echo 3. Aguardando os Pods ficarem prontos...
echo ==========================================
echo Aguardando SQL Server...
kubectl wait --namespace=fcg-tutorial --for=condition=ready pod -l app=sqlserver --timeout=120s
if %errorlevel% neq 0 (
    echo.
    echo [ERRO] O SQL Server demorou muito para subir.
    pause
    exit /b %errorlevel%
)

echo.
echo Aguardando FCG App...
kubectl wait --namespace=fcg-tutorial --for=condition=ready pod -l app=fcg-app --timeout=120s
if %errorlevel% neq 0 (
    echo.
    echo [ERRO] A Aplicacao FCG demorou muito para subir.
    pause
    exit /b %errorlevel%
)

echo.
echo Aguardando Games App...
kubectl wait --namespace=fcg-tutorial --for=condition=ready pod -l app=games-app --timeout=120s
if %errorlevel% neq 0 (
    echo.
    echo [ERRO] A Aplicacao Games demorou muito para subir.
    pause
    exit /b %errorlevel%
)

echo.
echo Aguardando Payments App...
kubectl wait --namespace=fcg-tutorial --for=condition=ready pod -l app=payments-app --timeout=120s
if %errorlevel% neq 0 (
    echo.
    echo [ERRO] A Aplicacao Payments demorou muito para subir.
    pause
    exit /b %errorlevel%
)

echo.
echo ==========================================
echo TUDO PRONTO!
echo ==========================================
echo Para acessar as aplicacoes, use terminais separados:
echo.
echo Terminal 1 (FCG):
echo kubectl port-forward service/fcg-service 8080:80 -n fcg-tutorial
echo.
echo Terminal 2 (Games):
echo kubectl port-forward service/games-service 8081:80 -n fcg-tutorial
echo.
echo Terminal 3 (Payments):
echo kubectl port-forward service/payments-service 8082:80 -n fcg-tutorial
echo.
echo FCG Swagger:      http://localhost:8080/swagger
echo Games Swagger:    http://localhost:8081/swagger
echo Payments Swagger: http://localhost:8082/swagger
pause
