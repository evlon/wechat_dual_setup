#!/bin/bash

# 微信双开自动化脚本
# 适用于 macOS 系统
# 作者：基于用户需求生成

set -e

# 配置变量
ORIGINAL_APP_NAME="WeChat.app"
CLONE_APP_NAME="WeChat2.app"
ORIGINAL_APP_PATH="/Applications/WeChat.app"
CLONE_APP_PATH="$HOME/Applications/$CLONE_APP_NAME"
BACKUP_APP_PATH="$HOME/Applications/$CLONE_APP_NAME"
BUNDLE_ID="com.tencent.xinWeChat2"
CERTIFICATE_NAME="WeChat2"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印彩色信息
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 检查权限
check_permissions() {
    info "检查管理员权限..."
    if [ "$EUID" -ne 0 ]; then
        error "需要管理员权限，请使用 sudo 运行此脚本"
        exit 1
    fi
}

# 检查原始微信应用
check_wechat_installation() {
    info "检查微信安装情况..."
    
    if [ -d "$ORIGINAL_APP_PATH" ]; then
        success "找到原始微信应用: $ORIGINAL_APP_PATH"
    elif [ -d "$HOME/Applications/WeChat.app" ]; then
        ORIGINAL_APP_PATH="$HOME/Applications/WeChat.app"
        success "找到原始微信应用: $ORIGINAL_APP_PATH"
    else
        error "未找到微信应用，请确保已安装微信"
        exit 1
    fi
}

# 检查证书
check_certificate() {
    info "检查代码签名证书..."
    
    if security find-identity -p codesigning | grep -q "$CERTIFICATE_NAME"; then
        success "找到代码签名证书: $CERTIFICATE_NAME"
    else
        warning "未找到证书 '$CERTIFICATE_NAME'，将使用 ad-hoc 签名"
        CERTIFICATE_NAME="-"
    fi
}

# 备份现有分身应用
backup_existing_clone() {
    if [ -d "$CLONE_APP_PATH" ]; then
        info "检测到已存在的分身应用，正在备份..."
        BACKUP_DIR="$HOME/Applications/WeChatBackup_$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$BACKUP_DIR"
        cp -R "$CLONE_APP_PATH" "$BACKUP_DIR/"
        success "已备份到: $BACKUP_DIR"
    fi
}

# 创建微信分身
create_wechat_clone() {
    info "正在创建微信分身..."
    
    # 删除已存在的分身
    if [ -d "$CLONE_APP_PATH" ]; then
        rm -rf "$CLONE_APP_PATH"
    fi
    
    # 复制应用
    info "复制微信应用文件..."
    cp -R "$ORIGINAL_APP_PATH" "$CLONE_APP_PATH"
    
    if [ -d "$CLONE_APP_PATH" ]; then
        success "微信分身创建成功: $CLONE_APP_PATH"
    else
        error "微信分身创建失败"
        exit 1
    fi
}

# 修改应用标识符
modify_bundle_identifier() {
    info "修改应用标识符..."
    
    if [ -f "$CLONE_APP_PATH/Contents/Info.plist" ]; then
        /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$CLONE_APP_PATH/Contents/Info.plist"
        
        # 验证修改
        NEW_BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$CLONE_APP_PATH/Contents/Info.plist")
        if [ "$NEW_BUNDLE_ID" = "$BUNDLE_ID" ]; then
            success "应用标识符修改成功: $BUNDLE_ID"
        else
            error "应用标识符修改失败"
            exit 1
        fi
    else
        error "找不到 Info.plist 文件"
        exit 1
    fi
}

# 重新签名应用
resign_application() {
    info "正在重新签名应用..."
    
    # 移除原有的签名
    codesign --remove-signature "$CLONE_APP_PATH" 2>/dev/null || true
    
    # 重新签名
    if codesign --force --deep --sign "$CERTIFICATE_NAME" "$CLONE_APP_PATH"; then
        success "应用签名成功"
        
        # 验证签名
        if codesign -v "$CLONE_APP_PATH" 2>/dev/null; then
            success "签名验证通过"
        else
            warning "签名验证失败，但应用可能仍可运行"
        fi
    else
        error "应用签名失败"
        exit 1
    fi
}

# 创建启动脚本
create_launch_script() {
    info "创建启动脚本..."
    
    LAUNCH_SCRIPT="$HOME/launch_wechat2.sh"
    cat > "$LAUNCH_SCRIPT" << 'EOF'
#!/bin/bash
nohup /Applications/WeChat2.app/Contents/MacOS/WeChat >/dev/null 2>&1 &
EOF
    
    chmod +x "$LAUNCH_SCRIPT"
    success "启动脚本创建成功: $LAUNCH_SCRIPT"
}

# 创建桌面快捷方式
create_desktop_shortcut() {
    info "创建桌面快捷方式..."
    
    # 在应用程序文件夹中创建别名
    osascript << EOF 2>/dev/null || true
try
    tell application "Finder"
        make new alias file to POSIX file "/Applications/WeChat2.app" at desktop
        set name of result to "微信分身"
    end tell
end try
EOF
    
    success "快捷方式创建完成"
}

# 完成提示
show_completion_message() {
    echo ""
    success "微信双开配置完成！"
    echo ""
    info "接下来您可以："
    echo "1. 先启动原始微信并登录第一个账号"
    echo "2. 使用以下任一方式启动第二个微信："
    echo "   - 直接打开 /Applications/WeChat2.app"
    echo "   - 运行: $HOME/launch_wechat2.sh"
    echo "   - 在程序坞中找到微信分身并固定"
    echo ""
    warning "注意：如果系统提示无法打开应用，请前往"
    warning "系统偏好设置 -> 安全性与隐私 -> 通用"
    warning "允许运行来自开发者的应用"
    echo ""
}

# 主函数
main() {
    echo "=================================================="
    echo "           微信双开自动化配置脚本"
    echo "=================================================="
    echo ""
    
    check_permissions
    check_wechat_installation
    check_certificate
    backup_existing_clone
    create_wechat_clone
    modify_bundle_identifier
    resign_application
    create_launch_script
    create_desktop_shortcut
    show_completion_message
}

# 运行主函数
main "$@"
