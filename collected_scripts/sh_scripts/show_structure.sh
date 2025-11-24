#!/bin/bash
echo "🌳 هيكل HyperFFactory - الهيكل المتكامل"
echo "======================================"

list_structure() {
    local indent="$1"
    local dir="$2"
    
    for item in "$dir"/*; do
        [ -e "$item" ] || continue
        
        name=$(basename "$item")
        
        # تخطى الملفات المخفية والمجلدات غير المرغوبة
        [[ $name == .* ]] && [[ $name != ".env.example" ]] && [[ $name != ".gitignore" ]] && continue
        [[ $name == "__pycache__" ]] || [[ $name == "*.log" ]] && continue
        
        if [ -d "$item" ]; then
            echo "${indent}📁 $name/"
            list_structure "${indent}  " "$item"
        else
            case "$name" in
                *.sh) icon="🛠️ " ;;
                *.yml|*.yaml) icon="⚙️ " ;;
                *.md) icon="📄 " ;;
                *.py) icon="🐍 " ;;
                Dockerfile) icon="🐳 " ;;
                .gitignore) icon="🔒 " ;;
                .env.example) icon="🔧 " ;;
                *) icon="📄 " ;;
            esac
            echo "${indent}${icon}$name"
        fi
    done
}

echo "."
list_structure "  " "."
