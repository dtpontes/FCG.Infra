@echo off
echo ==========================================
echo Deploy FCG no Azure AKS (Simplificado)
echo ==========================================
echo.

echo Aplicando Namespace...
kubectl apply -f k8s-tutorial/namespace.yaml

echo Aplicando SQL Server...
kubectl apply -f k8s-tutorial/sqlserver.yaml

echo Aplicando FCG Service...
kubectl apply -f k8s-tutorial/fcg-fixed.yaml

echo Aplicando Games Service...
kubectl apply -f k8s-tutorial/games.yaml

echo Aplicando Payments Service...
kubectl apply -f k8s-tutorial/payments.yaml

echo.
echo ==========================================
echo Configurando para Azure (LoadBalancer)...
echo ==========================================

echo Alterando FCG Service para LoadBalancer...
kubectl patch service fcg-service -n fcg-tutorial -p "{\"spec\":{\"type\":\"LoadBalancer\"}}"

echo Alterando Games Service para LoadBalancer...
kubectl patch service games-service -n fcg-tutorial -p "{\"spec\":{\"type\":\"LoadBalancer\"}}"

echo Alterando Payments Service para LoadBalancer...
kubectl patch service payments-service -n fcg-tutorial -p "{\"spec\":{\"type\":\"LoadBalancer\"}}"

echo.
echo ==========================================
echo Atualizando imagens do DockerHub...
echo ==========================================

echo Atualizando FCG para usar dtpontes/fcgpresentation...
kubectl set image deployment/fcg-app fcg-app=dtpontes/fcgpresentation:latest -n fcg-tutorial

echo Atualizando Games para usar dtpontes/fcggamespresentation...
kubectl set image deployment/games-app games-app=dtpontes/fcggamespresentation:latest -n fcg-tutorial

echo Atualizando Payments para usar dtpontes/fcgpaymentspresentation...
kubectl set image deployment/payments-app payments-app=dtpontes/fcgpaymentspresentation:latest -n fcg-tutorial

echo.
echo ==========================================
echo Aguardando Pods ficarem prontos...
echo ==========================================

echo Aguardando SQL Server...
kubectl wait --namespace=fcg-tutorial --for=condition=ready pod -l app=sqlserver --timeout=180s

echo Aguardando FCG App...
kubectl wait --namespace=fcg-tutorial --for=condition=ready pod -l app=fcg-app --timeout=180s

echo Aguardando Games App...
kubectl wait --namespace=fcg-tutorial --for=condition=ready pod -l app=games-app --timeout=180s

echo Aguardando Payments App...
kubectl wait --namespace=fcg-tutorial --for=condition=ready pod -l app=payments-app --timeout=180s

echo.
echo ==========================================
echo Aguardando IPs Publicos (30 segundos)...
echo ==========================================
timeout /t 30 /nobreak

echo.
echo ==========================================
echo DEPLOY CONCLUIDO!
echo ==========================================
kubectl get services -n fcg-tutorial
echo.
echo Acesse os servicos usando os EXTERNAL-IP acima:
echo FCG Swagger:      http://EXTERNAL-IP-FCG/swagger
echo Games Swagger:    http://EXTERNAL-IP-GAMES/swagger
echo Payments Swagger: http://EXTERNAL-IP-PAYMENTS/swagger
echo.
pause