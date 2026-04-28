#!/bin/bash

# 检查参数个数 (至少3个，第4个可选)
if [ $# -lt 3 ] || [ $# -gt 4 ]; then
    echo "错误：参数个数不正确！"
    echo "用法: $0 <分支名> <目标项目名> <目标模块名> [可选：release 或 snapshot]"
    echo "示例: $0 main my-project user-service"
    echo "示例: $0 main my-project user-service release"
    exit 1
fi

# 外层全局分支参数，绝对不可变
GLOBAL_BRANCH=$1
TARGET_PROJECT=$2
TARGET_MODULE=$3
OVERRIDE_TYPE=$4

BASE_DIR="/d/DeploySpace"
MAVEN_SETTINGS="/d/Maven/config/ncms-admin-test-settings.xml"
MAVEN_REPO="/e/Repository/test"

# 私服仓库配置 (请替换为实际账号密码)
NEXUS_USER="yourUsername"
NEXUS_PASS="yourPassword"

# 定义两个仓库地址
SNAPSHOT_REPO_URL="http://192.15.3.99:10390/repository/maven-credit-snapshots/"
RELEASE_REPO_URL="http://192.15.3.99:10390/repository/maven-credit-releases/"

# 注入高性能 JVM 参数
export MAVEN_OPTS="-Xms4g -Xmx8g -XX:MaxMetaspaceSize=1g -XX:+UseG1GC -XX:MaxGCPauseMillis=200"

echo "========================================="
echo "执行参数配置:"
echo "全局默认分支: $GLOBAL_BRANCH"
echo "目标项目: $TARGET_PROJECT"
echo "目标模块: $TARGET_MODULE"
echo "手动指定类型: ${OVERRIDE_TYPE:-[自动判断]}"
echo "========================================="

cd "$BASE_DIR" || { echo "无法进入目录 $BASE_DIR"; exit 1; }

# 第一阶段：循环更新并编译所有项目
echo ">>> 开始批量更新和编译所有项目..."
for project_dir in */; do
    project_name=${project_dir%/}
    echo "-----------------------------------------"
    echo "正在处理项目: $project_name"
    
    cd "$BASE_DIR/$project_name" || continue
    
    if [ ! -d ".git" ]; then
        echo "[$project_name] 不是 Git 仓库，跳过。"
        cd "$BASE_DIR"
        continue
    fi

    echo "[$project_name] 正在更新代码 (尝试分支: $GLOBAL_BRANCH) ..."
    git fetch --all --quiet
    
    # 核心逻辑：尝试切换，失败则进入交互模式
    CURRENT_BRANCH="" # 当前项目实际要用的分支
    
    if git checkout "$GLOBAL_BRANCH" 2>/dev/null; then
        # 自动切换成功
        CURRENT_BRANCH="$GLOBAL_BRANCH"
    else
        # 自动切换失败，打印原生的错误信息（去掉 2>/dev/null 让用户看到为什么失败）
        echo "⚠️ [$project_name] 自动切换到 '$GLOBAL_BRANCH' 失败！"
        git checkout "$GLOBAL_BRANCH" # 故意再执行一次，只为了把报错信息打出来
        
        # 进入交互式 while 循环
        while true; do
            read -p "👉 请手动输入 [$project_name] 要切换的分支名 (直接回车跳过该项目): " INPUT_BRANCH
            
            # 用户直接回车，输入为空，跳过当前项目
            if [ -z "$INPUT_BRANCH" ]; then
                echo "[$project_name] 用户选择跳过。"
                CURRENT_BRANCH="" # 置空作为跳过标记
                break
            fi
            
            # 尝试切换用户输入的分支
            if git checkout "$INPUT_BRANCH"; then
                echo "✅ [$project_name] 成功切换到手动指定的分支: $INPUT_BRANCH"
                CURRENT_BRANCH="$INPUT_BRANCH"
                break # 切换成功，跳出交互循环
            else
                echo "❌ 切换到 '$INPUT_BRANCH' 依然失败，请检查分支名或重新输入。"
            fi
        done
    fi

    # 判断是否拿到了有效的分支名
    if [ -z "$CURRENT_BRANCH" ]; then
        cd "$BASE_DIR"
        continue 2 # 跳过当前项目的后续操作，进入 for 循环的下一个项目 (注意这里的 2)
    fi

    # 只有切换成功，才执行强制重置 (使用当前项目确定的分支)
    echo "[$project_name] 正在强制重置到 origin/$CURRENT_BRANCH ..."
    git reset --hard "origin/$CURRENT_BRANCH"

    echo "[$project_name] 开始 Maven 编译..."
    mvn -gs "$MAVEN_SETTINGS" \
        -Dmaven.repo.local="$MAVEN_REPO" \
        -T 8C clean install -U -Dmaven.test.skip=true \
        -Dmaven.compiler.fork=true \
        -Dmaven.compiler.maxmem=2g
        
    if [ $? -ne 0 ]; then
        echo "[$project_name] 编译失败！跳过该项目，继续执行下一个..."
    else
        echo "[$project_name] 编译成功！"
    fi
    
    cd "$BASE_DIR"
done

echo "========================================="
echo ">>> 所有项目批量处理完成。"
echo "========================================="

# 第二阶段：进入指定项目，查找模块，判断版本并部署
TARGET_DIR="$BASE_DIR/$TARGET_PROJECT"
if [ ! -d "$TARGET_DIR" ]; then
    echo "错误: 找不到目标项目 '$TARGET_DIR'"
    exit 1
fi
cd "$TARGET_DIR" || { echo "无法进入目标项目 $TARGET_DIR"; exit 1; }
echo ">>> 已进入目标项目: $TARGET_PROJECT"

# 查找目标模块的POM文件
MODULE_PATH=$(find . -maxdepth 3 -type d -name "$TARGET_MODULE" | head -n 1)
if [ -z "$MODULE_PATH" ]; then
    echo "错误: 在项目 '$TARGET_PROJECT' 中找不到模块 '$TARGET_MODULE'"
    exit 1
fi
MODULE_PL_PATH=${MODULE_PATH#./}
POM_FILE="$MODULE_PATH/pom.xml"
if [ ! -f "$POM_FILE" ]; then
    echo "错误: 在模块目录 '$MODULE_PATH' 中找不到 pom.xml"
    exit 1
fi
echo ">>> 找到目标模块路径: $MODULE_PL_PATH"

# 提取版本号并判断类型
PROJECT_VERSION=$(grep -oP '(?<=<version>).*?(?=</version>)' "$POM_FILE" | head -n 1)
if [ -z "$PROJECT_VERSION" ]; then
    echo "错误: 无法从 pom.xml 中解析出版本号。"
    exit 1
fi
echo ">>> 解析到模块版本: $PROJECT_VERSION"

# 自动判断版本类型
if [[ "$PROJECT_VERSION" == *"-SNAPSHOT"* ]]; then
    VERSION_TYPE="snapshot"
else
    VERSION_TYPE="release"
fi

# 确定最终使用的版本类型
if [ -n "$OVERRIDE_TYPE" ]; then
    echo "⚠️ 手动指定了类型 '$OVERRIDE_TYPE'，覆盖自动判断结果 '$VERSION_TYPE'。"
    FINAL_TYPE="$OVERRIDE_TYPE"
else
    FINAL_TYPE="$VERSION_TYPE"
fi

echo ">>> 最终确定的版本类型: $FINAL_TYPE"

# 根据最终类型选择仓库地址和认证ID
if [ "$FINAL_TYPE" == "release" ]; then
    DEPLOY_REPO_URL="$RELEASE_REPO_URL"
    REPO_ID="nexus-releases"
else
    DEPLOY_REPO_URL="$SNAPSHOT_REPO_URL"
    REPO_ID="nexus-snapshots"
fi

echo ">>> 将推送到仓库: $DEPLOY_REPO_URL (ID: $REPO_ID)"

# 执行最终部署
echo ">>> 开始将模块 '$TARGET_MODULE' 推送至私服..."
mvn -gs "$MAVEN_SETTINGS" \
    -Dmaven.repo.local="$MAVEN_REPO" \
    -T 8C clean deploy \
    -pl="$MODULE_PL_PATH" -am \
    -U \
    -Dmaven.test.skip=true \
    -DaltDeploymentRepository=${REPO_ID}::default::${DEPLOY_REPO_URL} \
    -Dmaven.wagon.http.auth.preemptive=true \
    -Dmaven.wagon.http.user.${REPO_ID}=${NEXUS_USER} \
    -Dmaven.wagon.http.pass.${REPO_ID}=${NEXUS_PASS} \
    -Dmaven.compiler.fork=true \
    -Dmaven.compiler.maxmem=2g

if [ $? -eq 0 ]; then
    echo "========================================="
    echo "✅ 成功！模块 '$TARGET_MODULE' (版本: $PROJECT_VERSION, 类型: $FINAL_TYPE) 已推送到 '$DEPLOY_REPO_URL'。"
    echo "========================================="
else
    echo "========================================="
    echo "❌ 失败！模块推送出错，请检查日志。"
    echo "========================================="
    exit 1
fi