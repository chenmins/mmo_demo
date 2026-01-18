@echo off
chcp 65001 >nul
echo ==========================================
echo 正在从 origin 拉取所有分支信息...
echo ==========================================
git fetch origin --prune

if %errorlevel% neq 0 (
    echo [错误] 无法连接到 origin。
    pause
    exit /b
)

echo.
echo ==========================================
echo 正在将所有 origin 分支推送到 chenmins...
echo ==========================================
:: 这里的双引号很重要，防止通配符被 Shell 错误解析
git push chenmins "refs/remotes/origin/*:refs/heads/*"

echo.
echo ==========================================
echo 正在推送标签 (Tags)...
echo ==========================================
git push chenmins --tags

echo.
echo ==========================================
echo 操作完成！
echo ==========================================
pause
