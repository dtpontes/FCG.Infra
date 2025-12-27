@echo off
echo ==========================================
echo Obtendo Link do Application Insights
echo ==========================================
echo.

REM Configurações
set RESOURCE_GROUP=FCG-Infra
set APP_INSIGHTS_NAME=fcg-appinsights

echo Obtendo informacoes da assinatura...
for /f "tokens=*" %%i in ('az account show --query id -o tsv') do set SUBSCRIPTION_ID=%%i
for /f "tokens=*" %%i in ('az account show --query name -o tsv') do set SUBSCRIPTION_NAME=%%i

echo.
echo ==========================================
echo Informacoes da Assinatura:
echo ==========================================
echo Nome: %SUBSCRIPTION_NAME%
echo ID: %SUBSCRIPTION_ID%
echo.

echo ==========================================
echo Application Insights:
echo ==========================================
echo Resource Group: %RESOURCE_GROUP%
echo Nome: %APP_INSIGHTS_NAME%
echo.

echo ==========================================
echo Link do Portal (Copie e Cole):
echo ==========================================
echo.
echo Opcao 1 (Link Simples):
echo https://portal.azure.com/#@/resource/subscriptions/%SUBSCRIPTION_ID%/resourceGroups/%RESOURCE_GROUP%/providers/microsoft.insights/components/%APP_INSIGHTS_NAME%/overview
echo.
echo Opcao 2 (Link Direto - se a Opcao 1 nao funcionar):
echo https://portal.azure.com/#view/AppInsightsExtension/ComponentDetailsBladeV2/ComponentId/%%2Fsubscriptions%%2F%SUBSCRIPTION_ID%%%2FresourceGroups%%2F%RESOURCE_GROUP%%%2Fproviders%%2Fmicrosoft.insights%%2Fcomponents%%2F%APP_INSIGHTS_NAME%
echo.

echo ==========================================
echo Atalho: Abrir no Navegador Padrao
echo ==========================================
set /p open="Deseja abrir o Application Insights no navegador? (S/N): "
if /i "%open%"=="S" (
    start https://portal.azure.com/#@/resource/subscriptions/%SUBSCRIPTION_ID%/resourceGroups/%RESOURCE_GROUP%/providers/microsoft.insights/components/%APP_INSIGHTS_NAME%/overview
    echo.
    echo Portal aberto! Faca login se necessario.
)

echo.
echo ==========================================
echo Comandos Uteis:
echo ==========================================
echo Ver detalhes do Application Insights:
echo az monitor app-insights component show --app %APP_INSIGHTS_NAME% --resource-group %RESOURCE_GROUP%
echo.
echo Ver Instrumentation Key:
echo az monitor app-insights component show --app %APP_INSIGHTS_NAME% --resource-group %RESOURCE_GROUP% --query instrumentationKey -o tsv
echo.
echo Ver Connection String:
echo az monitor app-insights component show --app %APP_INSIGHTS_NAME% --resource-group %RESOURCE_GROUP% --query connectionString -o tsv
echo.

pause
