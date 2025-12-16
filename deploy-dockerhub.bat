@echo off
set /p DOCKER_USER="Digite seu usuario do DockerHub: "

echo.
echo ==========================================
echo 1. Login no DockerHub
echo ==========================================
docker login
if %errorlevel% neq 0 exit /b %errorlevel%

echo.
echo ==========================================
echo 2. Construindo e Enviando Imagens (Push)
echo ==========================================

echo [1/3] FCG Presentation...
docker build -t %DOCKER_USER%/fcg-presentation:latest -f FCG\src\FCG.Presentation\Dockerfile FCG
docker push %DOCKER_USER%/fcg-presentation:latest

echo [2/3] Games Presentation...
docker build -t %DOCKER_USER%/games-presentation:latest -f Games\src\FCG.Games.Presentation\Dockerfile Games
docker push %DOCKER_USER%/games-presentation:latest

echo [3/3] Payments Presentation...
docker build -t %DOCKER_USER%/payments-presentation:latest -f Payments\src\FCG.Payments.Presentation\Dockerfile Payments
docker push %DOCKER_USER%/payments-presentation:latest

echo.
echo ==========================================
echo 3. Atualizando Kustomization.yaml
echo ==========================================
echo ATENCAO: Para que o Kubernetes baixe as imagens corretas,
echo voce precisa editar o arquivo k8s-tutorial\kustomization.yaml
echo e trocar 'SEU_USUARIO' pelo seu usuario: %DOCKER_USER%
echo.
echo Vou abrir o arquivo para voce editar agora...
notepad k8s-tutorial\kustomization.yaml
pause

echo.
echo ==========================================
echo 4. Deploy no Kubernetes
echo ==========================================
kubectl apply -k k8s-tutorial

echo.
echo ==========================================
echo TUDO PRONTO!
echo ==========================================
echo Verifique os pods: kubectl get pods -n fcg-tutorial
pause