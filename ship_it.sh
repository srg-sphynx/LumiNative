#!/bin/bash

# 1. Add any new files (License, etc)
git add .
git commit -m "Preparing for V3.0.0 Release: Added License and final polish"

# 2. Push to GitHub
echo "🚀 Pushing code to GitHub..."
git push -u origin main

# 3. Instructions for Release
echo ""
echo "---------------------------------------------------"
echo "✅ Code pushed successfully!"
echo ""
echo "📦 APP RELEASE INSTRUCTIONS:"
echo "Since the 'gh' CLI is not installed, you must create the release manually:"
echo ""
echo "1. Open this URL: https://github.com/srg-sphynx/LumiNative/releases/new"
echo "2. Create a new tag: v3.0.0"
echo "3. Title: 'LumiNative V3 - Liquid Glass Edition'"
echo "4. Drag and drop the installer file from here:"
echo "   👉 /Users/saketareddy/Downloads/MonitorControl_V3.0.0.dmg"
echo ""
echo "---------------------------------------------------"
