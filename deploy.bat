@echo off
REM ============================================
REM  StorApp 后端一键部署脚本
REM  前置条件: JDK 1.8 / Maven 3.x / MySQL 8.0 / Redis
REM ============================================

echo ========================================
echo   StorApp 后端部署脚本
echo ========================================
echo.

REM --- 检查 Java ---
java -version >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Java 未安装！请先安装 JDK 1.8
    pause
    exit /b 1
)
echo [OK] Java 已就绪

REM --- 检查 Maven ---
mvn -version >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Maven 未安装！请先安装 Maven 3.x
    pause
    exit /b 1
)
echo [OK] Maven 已就绪

REM --- 检查 MySQL ---
mysql --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [WARN] MySQL 命令行未找到，请确认 MySQL 服务已启动
)

REM --- 导入数据库（首次运行）---
echo.
echo [INFO] 如需导入数据库，请手动执行:
echo   mysql -u root -p -e "CREATE DATABASE IF NOT EXISTS java_dev DEFAULT CHARSET utf8mb4;"
echo   mysql -u root -p java_dev ^< crmeb\sql\Crmeb_v3.0.sql
echo.

REM --- Maven 构建 ---
echo [INFO] 开始 Maven 编译打包...
cd /d "%~dp0crmeb"
call mvn clean package -DskipTests
if %errorlevel% neq 0 (
    echo [ERROR] Maven 构建失败！
    pause
    exit /b 1
)
echo [OK] Maven 构建成功

REM --- 启动 Admin 后端 ---
echo.
echo [INFO] 启动 Admin 后端 (端口 20600)...
start "StorApp-Admin" java -jar "%~dp0crmeb\crmeb-admin\target\crmeb-admin-0.0.1-SNAPSHOT.jar" --spring.profiles.active=dev

REM --- 启动 Front 后端 ---
echo [INFO] 启动 Front API (端口 20610)...
start "StorApp-Front" java -jar "%~dp0crmeb\crmeb-front\target\crmeb-front-0.0.1-SNAPSHOT.jar" --spring.profiles.active=dev

echo.
echo ========================================
echo   部署完成！
echo   Admin 后端: http://localhost:20600
echo   Front API:  http://localhost:20610
echo   Admin 前端: cd admin ^&^& npm run dev
echo ========================================
pause