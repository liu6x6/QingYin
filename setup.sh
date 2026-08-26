#!/bin/bash
set -e

echo "🎵 清音 (QingYin) 项目设置脚本"
echo ""

# 检查 XcodeGen
if ! command -v xcodegen &> /dev/null; then
    echo "⚠️  XcodeGen 未安装"
    echo "正在尝试安装..."
    if command -v brew &> /dev/null; then
        brew install xcodegen
    else
        echo "❌ 请先安装 Homebrew，然后运行: brew install xcodegen"
        exit 1
    fi
fi

echo "✅ XcodeGen 已安装"
echo ""

# 生成 Xcode 工程
echo "🔨 正在生成 Xcode 工程..."
xcodegen generate

echo ""
echo "✅ 工程生成完成: QingYin.xcodeproj"
echo ""

# 打开工程
read -p "是否现在打开 Xcode 工程？(y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    open QingYin.xcodeproj
fi
