#!/bin/bash

# 创建项目目录结构的脚本
# 只创建文件夹和generate_lst.sh，不执行生成.lst文件的操作

# 获取当前时间并格式化为年月日时分
current_time=$(date +"%Y%m%d%H%M")

# 设置根目录名称（V+当前年月日时分）
root_dir="V${current_time}"

echo "开始创建项目目录结构..."

# 创建主目录
mkdir -p "$root_dir"

# 创建子目录结构
mkdir -p "$root_dir/Backend"
mkdir -p "$root_dir/Frontend/FK"
mkdir -p "$root_dir/Frontend/H5"
mkdir -p "$root_dir/Frontend/WEB"
mkdir -p "$root_dir/Database/ecms_astprsrvt_资产保全数据库"
mkdir -p "$root_dir/Database/ecms_collateral_押品管理数据库"
mkdir -p "$root_dir/Database/ecms_credit_control_额度管理数据库"
mkdir -p "$root_dir/Database/ecms_credit_信贷业务数据库"
mkdir -p "$root_dir/Database/ecms_distributed_分布式事务数据库"
mkdir -p "$root_dir/Database/ecms_edoc_电子档案数据库"
mkdir -p "$root_dir/Database/ecms_external_data_外数处理数据库"
mkdir -p "$root_dir/Database/ecms_ipc_天元运行态数据库"
mkdir -p "$root_dir/Database/ecms_nacos_注册配置中心数据库"
mkdir -p "$root_dir/Database/ecms_qa_智能问答数据库"
mkdir -p "$root_dir/Database/ecms_rms_dc_决策中心数据库"
mkdir -p "$root_dir/Database/ecms_rms_mc_模型中心数据库"
mkdir -p "$root_dir/Database/ecms_rule_规则引擎数据库"
mkdir -p "$root_dir/Database/ecms_sentinel_熔断限流数据库"
mkdir -p "$root_dir/Database/ecms_topconfig_天元网关数据库"
mkdir -p "$root_dir/Database/ecms_workflow_流程引擎数据库"
mkdir -p "$root_dir/Database/ecms_xxl_job_批量调度数据库"
mkdir -p "$root_dir/EdocFile"

echo "目录结构创建完成"


# 拷贝《新信贷版本迭代更新操作手册》至部署包中
echo "开始拷贝手册....."
cp 新信贷版本迭代更新操作手册.docx "$root_dir"
echo ".....拷贝手册完成"

# 创建发布包脚本的函数
create_deploy_generate_script() {
    local target_dir="$1"
    
    cat > "$target_dir/generate_deploy_pkg.sh" << 'EOF'
#!/bin/bash

# 生成 update-当前年月日时分.lst 文件的脚本
# 将前端包打包成.zip文件，并将文件放置在规定路径目录下
# 生成前端发版操作文件
# 生成版本文件清单
# 将全量版本文件压缩为zip包


deploy_dir="$(pwd)"
deploy_dir_name=$(basename "$(pwd)")
# 获取版本号日期参数，格式为年月日
current_date=${deploy_dir_name:1:8}
# 获取版本号时间参数，格式为年月日时分
current_time=${deploy_dir_name:1:12}
update_list_file="update-${current_time}.lst"
temp_dir="${deploy_dir_name}_temp"
base_dir="$deploy_dir/$temp_dir"
deploy_file_list="新信贷发版文件清单_$current_time.csv"


declare -A BACK_MATCH #
declare -A FRONT_MATCH #

# 后端映射数组
BACK_MATCH["tansun-tcp-system-boot.jar"]="系统管理服务（注意：系统管理第一个发）,ecms-system";
BACK_MATCH["tansun-tcp-airobot-boot.jar"]="智能问答服务,ecms-airobot";
BACK_MATCH["tcp-auth-server.jar"]="认证中心服务,ecms-auth";
BACK_MATCH["tansun-tcp-collateral-boot.jar"]="押品管理服务,ecms-collateral";
BACK_MATCH["tansun-tcp-common-boot.jar"]="综合能力中心,ecms-common";
BACK_MATCH["tansun-tcp-contract-loan-boot.jar"]="合同放还款服务,ecms-contract";
BACK_MATCH["tansun-tcp-corporate-boot.jar"]="对公能力中心,ecms-corporate";
BACK_MATCH["tansun-tcp-custmanage-boot.jar"]="客户管理服务,ecms-cust";
BACK_MATCH["tansun-tcp-docmanage-boot.jar"]="档案中心服务,ecms-docmanage";
BACK_MATCH["tansun-tcp-edoc-boot.jar"]="电子文档服务,ecms-edoc";
BACK_MATCH["external-data-boot.jar"]="外数处理中心,ecms-external-data";
BACK_MATCH["tansun-tcp-hierarchy-boot.jar"]="分层分域分级,ecms-hierarchy";
BACK_MATCH["tansun-tcp-interest-rate-boot.jar"]="利率定价中心,ecms-interest-rate";
BACK_MATCH["ipc-run-boot.jar"]="天元运行态服务,ecms-ipc";
BACK_MATCH["tansun-tcp-creditcontrol-boot.jar"]="额度管理服务,ecms-limit-mgt";
BACK_MATCH["tansun-tcp-message-boot.jar"]="消息中心服务,ecms-message";
BACK_MATCH["gateway.jar"]="门户网关服务,ecms-portal";
BACK_MATCH["tansun-tcp-postloan-boot.jar"]="贷后管理服务,ecms-post-loan";
BACK_MATCH["tansun-tcp-pd-boot.jar"]="产品管理服务,ecms-product";
BACK_MATCH["tansun-tcp-businessrating-boot.jar"]="评级中心服务,ecms-rate";
BACK_MATCH["tansun-tcp-retail-boot.jar"]="零售能力中心,ecms-retail";
BACK_MATCH["tansun-tcp-astprsrvt-boot.jar"]="风险资产服务,ecms-risk-asset";
BACK_MATCH["rule-boot-platform-start.jar"]="规则引擎服务,ecms-rule-platform";
BACK_MATCH["tansun-tcp-statistics-boot.jar"]="统计查询中心,ecms-statistics";
BACK_MATCH["ty-gateway-boot.jar"]="天元网关服务,ecms-ty-gateway";
BACK_MATCH["tansun-tcp-workflow-boot.jar"]="流程引擎服务,ecms-workflow";
BACK_MATCH["xxljob-admin-2.3.0.jar"]="批量调度服务,ecms-xxl-job";
BACK_MATCH["rule-platform-mc-boot.jar"]="模型中心服务,ecms-fk-model";
BACK_MATCH["rule-platform-dc-boot.jar"]="决策引擎服务,ecms-fk-rule";
BACK_MATCH["sentinel-dashboard.jar"]="熔断限流服务,ecms-sentinel";
BACK_MATCH["tansun-tcp-batch-boot.jar"]="批处理中心,ecms-batch";


# 前端映射数组
FRONT_MATCH["h5_vue.zip"]="移动端(面客),dmzweb-h5,h5前端";
FRONT_MATCH["airobot_vue.zip"]="PC端前端服务,pc-front,智能问答前端";
FRONT_MATCH["chn_vue.zip"]="PC端前端服务,pc-front,PAD端子应用前端";
FRONT_MATCH["cltl_vue.zip"]="PC端前端服务,pc-front,押品管理前端";
FRONT_MATCH["cprsv_vue.zip"]="PC端前端服务,pc-front,综合信贷业务平台";
FRONT_MATCH["crline_vue.zip"]="PC端前端服务,pc-front,用信管理前端";
FRONT_MATCH["cst_vue.zip"]="PC端前端服务,pc-front,客户管理前端";
FRONT_MATCH["ctr_vue.zip"]="PC端前端服务,pc-front,合同管理前端";
FRONT_MATCH["dsbr_vue.zip"]="PC端前端服务,pc-front,放款管理前端";
FRONT_MATCH["edoc_vue.zip"]="PC端前端服务,pc-front,电子文档前端";
FRONT_MATCH["files_vue.zip"]="PC端前端服务,pc-front,档案管理前端";
FRONT_MATCH["intrt_vue.zip"]="PC端前端服务,pc-front,利率管理前端";
FRONT_MATCH["lmt_vue.zip"]="PC端前端服务,pc-front,额度管理前端";
FRONT_MATCH["offbalshet_vue.zip"]="PC端前端服务,pc-front,表外及中间业务平台";
FRONT_MATCH["pad_vue.zip"]="PC端前端服务,pc-front,PAD端统一门户";
FRONT_MATCH["pd_vue.zip"]="PC端前端服务,pc-front,产品管理前端";
FRONT_MATCH["portal_vue.zip"]="PC端前端服务,pc-front,PC端统一门户";
FRONT_MATCH["pstloan_vue.zip"]="PC端前端服务,pc-front,贷后管理前端";
FRONT_MATCH["repy_vue.zip"]="PC端前端服务,pc-front,还款管理前端";
FRONT_MATCH["rsk_vue.zip"]="PC端前端服务,pc-front,风险资产管理前端";
FRONT_MATCH["rtg_vue.zip"]="PC端前端服务,pc-front,评级管理前端";
FRONT_MATCH["rule_vue.zip"]="PC端前端服务,pc-front,规则引擎前端";
FRONT_MATCH["stat_vue.zip"]="PC端前端服务,pc-front,统计查询前端";
FRONT_MATCH["stm_vue.zip"]="PC端前端服务,pc-front,系统管理前端";
FRONT_MATCH["workflow_vue.zip"]="PC端前端服务,pc-front,流程中心前端";
FRONT_MATCH["xxljob_vue.zip"]="PC端前端服务,pc-front,调度平台前端";
FRONT_MATCH["dc_vue.zip"]="风控前端服务,fk-front,风控规则引擎前端";
FRONT_MATCH["mc_vue.zip"]="风控前端服务,fk-front,风控模型中心前端";


# ======================函数=========================

# 函数：日志打印函数
log() {
  echo "[$(date "+%Y-%m-%d %H:%M:%S")] $1"
}

# 函数：获取相对路径
get_rel_path() {
  rel_path=$(realpath  --relative-to="." "$1")
  echo "./$rel_path"
}

# 函数：压缩文件夹
compress_pkg() {
  local source_folder=$1
  local targer_pkg=$2
  
  log "开始压缩文件，将 $(get_rel_path $source_folder) 压缩为 $(get_rel_path $targer_pkg)"
  
  # 判断是否存在7z压缩方法
  if command -v 7z &> /dev/null; then
    log "正在使用7zip压缩文件。请稍后......"
	7z a -tzip "$targer_pkg" "$source_folder/*"
	log "使用7zip压缩完成"
    echo
	return 0
  fi
  
  # 用原生压缩方法兜底，但压缩很慢
  log "正在使用powershell压缩文件。耗时较久，请稍后......"
  powershell.exe -Command "Compress-Archive -Path '$source_folder/*' -DestinationPath '$targer_pkg'"
  log "使用powershell压缩完成"
  echo  
  return 0
}

# 函数：创建处理文件夹并复制文件
create_operate_folder() {
  # 创建操作文件夹
  log "创建临时操作文件夹 $base_dir"
  
  mkdir "$base_dir"
  
  # 复制版本文件
  log "复制发布版本文件至临时操作文件夹"
  log "复制发布版本文件 ./Backend/"
  cp -r ./Backend/ "$temp_dir/"
  
  log "复制发布版本文件 ./Database/"
  cp -r ./Database/ "$temp_dir/"
  
  log "复制发布版本文件 ./EdocFile/"
  cp -r ./EdocFile/ "$temp_dir/"
  
  log "复制发布版本文件 ./Frontend/"
  cp -r ./Frontend/ "$temp_dir/"
  
  log "发布版本文件复制完毕"
  echo
  
  # 删除空文件夹
  log "删除下列空文件夹："
  find "$base_dir/" -type d -empty -print
  find "$base_dir/" -type d -empty -delete
  
  log "临时操作文件夹 $base_dir 创建完毕"
  echo
}

# 函数：生成 update-当前年月日时分.lst 文件
generate_lst_script() {
  local target_dir="$1"
  log "生成lst文件，目录 $(get_rel_path $target_dir)"
  
  # 删除文件夹下的.lst文件
  rm -rf "$target_dir/"update-*.lst

  # 清空或创建输出文件
  update_list_file_path="$target_dir/$update_list_file"
  > "$update_list_file_path"

  # 遍历目录下的所有zip文件
  for file in "$target_dir"/*.zip; do
      # 跳过目录
      if [ -d "$file" ]; then
          continue
      fi

      # 提取文件名（不带路径）
      filename=$(basename "$file")

      # 提取项目名（去掉 .zip 后缀）
      project_name="${filename%.zip}"

      # 生成并写入符合格式的行
      echo "/home/yw/deploy-web/#${filename}#/home/yw/nginx-1.28.0/html/${project_name}#${filename}#dist#" >> "$update_list_file_path"

      log "已处理: $filename -> 项目名: $project_name"
  done

  log "========================================"
  log "已生成文件: $(get_rel_path $update_list_file_path)"
  log "共处理了 $(grep -c "" "$update_list_file_path") 个zip文件"
  log "========================================"
  echo

  # 显示生成的文件内容
  log "$(basename "$target_dir")前端发版lst文件内容预览:"
  cat "$update_list_file_path"
  echo
}

# 函数：前端文件打包
pkg_frontend() {
  local frontend_dir="$base_dir/Frontend"
  local frontend_group="$1"
  log "=====开始=前端 $1 打包====="

  # 创建前端文件夹
  pkg_frontend_zip_dir="$frontend_dir/$current_date/$current_time/Frontend"
  if [ ! -d "pkg_frontend_zip_dir" ]; then
    log "$pkg_frontend_zip_dir 文件夹不存在，开始创建文件夹"
    mkdir -p "$pkg_frontend_zip_dir"
    log "$(get_rel_path $pkg_frontend_zip_dir) 文件夹已创建"
  fi

  if [ -f "$frontend_dir/$1.zip" ]; then
    log "文件$(get_rel_path $frontend_dir/$1.zip)已存在，先执行删除操作"
    rm -rf "$frontend_dir/$1.zip"
    log "文件$(get_rel_path $frontend_dir/$1.zip)删除完毕"
  fi
  
  log "开始压缩前端包 $(get_rel_path ./$temp_dir/Frontend/$1) "
  # powershell.exe -Command "Compress-Archive -Path './$temp_dir/Frontend/$1/*' -DestinationPath './$temp_dir/Frontend/$1.zip'"
  compress_pkg "./$temp_dir/Frontend/$1" "./$temp_dir/Frontend/$1.zip"
  log "前端包 $(get_rel_path ./$temp_dir/Frontend/$1) 压缩完毕"
  
  # 将前端压缩包移动至前端不是文件夹内
  mv "$frontend_dir/$1.zip" "$pkg_frontend_zip_dir/"

  # 删除原前端文件夹
  log "删除已处理前端文件夹 $(get_rel_path $frontend_dir/$1)"
  rm -rf "$frontend_dir/$1"
  
  log "=====结束=前端 $1 打包====="
  echo
}

# 函数：生成前端操作文件
generate_front_deploy_file() {
  log "开始生成前端操作文件"

  local frontend_group="$1"
  local frontend_dir="$base_dir/Frontend"
  
  deploy_file_name="新信贷-前端发版步骤-$current_time.txt"
  if [ ! -f "$frontend_dir/$deploy_file_name" ]; then
    printf "将$current_date文件夹上传至OSS的IN桶的prod文件夹中" > "$frontend_dir/$deploy_file_name"
  fi
  
  printf "\n" >> "$frontend_dir/$deploy_file_name"
  printf "#=========================================================\n" >> "$frontend_dir/$deploy_file_name"
  printf "\n" >> "$frontend_dir/$deploy_file_name"
  printf "# $frontend_group\n" >> "$frontend_dir/$deploy_file_name"
  printf "\n" >> "$frontend_dir/$deploy_file_name"
  printf "## 1.执行前端发版命令\n" >> "$frontend_dir/$deploy_file_name"
  printf "cd /home/yw/update/deploy-script && ls -lrt\n" >> "$frontend_dir/$deploy_file_name"
  printf "\n" >> "$frontend_dir/$deploy_file_name"
  printf "sh ECMS-WEB-TOTAL.sh $current_time $current_date $frontend_group\n" >> "$frontend_dir/$deploy_file_name"
  printf "\n" >> "$frontend_dir/$deploy_file_name"
  printf "## 2.查看服务更新时间\n" >> "$frontend_dir/$deploy_file_name"
  printf "ps -ef | grep nginx\n" >> "$frontend_dir/$deploy_file_name" 
  printf "\n" >> "$frontend_dir/$deploy_file_name"
  printf "## 3.查看发布包md5值\n" >> "$frontend_dir/$deploy_file_name"
  printf "cd /home/yw/update/$current_time && grep md5 $current_time.log\n" >> "$frontend_dir/$deploy_file_name" 
  printf "\n" >> "$frontend_dir/$deploy_file_name"
  
  log "前端操作文件 $(get_rel_path $frontend_dir/$deploy_file_name) 生成完毕"
  echo
}

# 函数：生成发版文件清单
generate_deploy_file_list() {
  log "开始生成发版文件清单"
  
  local deploy_file="$base_dir/$deploy_file_list"
  if [ ! -f $deploy_file ]; then
    log "文件$deploy_file_list不存在，先创建文件"
    > "$deploy_file"
    log "文件$(get_rel_path $deploy_file)创建完毕"
  fi
  
  # 脚本清单添加
  local db_dir="$base_dir/Database"
  if [ -d "$db_dir" ]; then
    echo "脚本" >> "$deploy_file"
	# find $db_dir -print | sed -e 's;[^/]*/;,;g;s;,;,;g' >> "$deploy_file"
	echo "脚本路径,脚本名称,打包md5值,发版md5值" >> "$deploy_file"
	find ./Database/ -type f -exec md5sum {} + | awk '{
    	md5 = $1;
    	full_path = $2;
    	temp_path = full_path
    	sub(/.*\//, "", temp_path);
    	file_name = temp_path
        print full_path "," file_name "," md5;
    }' >> "$deploy_file"
	echo -e "\n" >> "$deploy_file"
  fi
  
  # 后端清单添加
  local back_dir="$base_dir/Backend"
  if [ -d "$back_dir" ]; then
    echo "后端" >> "$deploy_file"
	echo "部署服务名称,服务器分组,后端包名,打包md5值,发版md5值" >> "$deploy_file"

	for back_md5_file in $back_dir/*.md5; do
      back_pkg_md5=`cat $back_md5_file | awk '{print $1}'`
      back_pkg=`cat $back_md5_file | awk '{print $2}'`
      back_pkg_name=${back_pkg:2}
      echo "${BACK_MATCH[${back_pkg_name}]},$back_pkg_name,$back_pkg_md5" >> "$deploy_file"
    done

	echo -e "\n" >> "$deploy_file"
  fi
  
  # 前端清单添加
  local front_dir="$base_dir/Frontend"
  if [ -d "$front_dir" ]; then
    echo "前端" >> "$deploy_file"
	echo "前端服务名称,前端服务分组,前端包名称,前端包,打包md5值,发版md5值" >> "$deploy_file"

    for front_md5_file in $(find ./Frontend/ -type f -name "*.md5" -print0 | xargs -0); do
      front_pkg_md5=`cat $front_md5_file | awk '{print $1}'`
      front_pkg=`cat $front_md5_file | awk '{print $2}'`
      front_pkg_name=${front_pkg:2}
      echo "${FRONT_MATCH[${front_pkg_name}]},$front_pkg_name,$front_pkg_md5" >> "$deploy_file"
    done
	
	echo -e "\n" >> "$deploy_file"
  fi
  
  # 电子文档清单添加
  local edoc_dir="$base_dir/EdocFile"
  if [ -d "$edoc_dir" ]; then
    echo "电子文档" >> "$deploy_file"
	# find ./EdocFile -print | sed -e 's;[^/]*/;,;g;s;,;,;g' >> "$deploy_file"
	echo "文档路径,文档名称,打包md5值,发版md5值" >> "$deploy_file"
	find ./EdocFile/ -type f -exec md5sum {} + | awk '{
    	md5 = $1;
    	full_path = $2;
    	temp_path = full_path
    	sub(/.*\//, "", temp_path);
    	file_name = temp_path
        print full_path "," file_name "," md5;
    }' >> "$deploy_file"
	echo -e "\n" >> "$deploy_file"
	echo -e "\n" >> "$deploy_file"
  fi
  
  log "发版文件清单 $(get_rel_path $deploy_file) 生成完毕"
  echo
}

# ======================函数=========================



# =====================任务脚本=====================
# 开始时间
deploy_pkg_start_time=$(date +%s)
log "**********************************************"
log "*******开始处理版本$deploy_dir_name发布包********"
log "********开始时间：$(date -d @$deploy_pkg_start_time '+%Y-%m-%d %H:%M:%S')*********"
log "**********************************************"
echo

# 创建处理文件夹
create_operate_folder

# 拷贝《新信贷版本迭代更新操作手册》至部署包中
log "开始拷贝手册《新信贷版本迭代更新操作手册.docx》....."
cp 新信贷版本迭代更新操作手册.docx "$base_dir"
log "手册《新信贷版本迭代更新操作手册.docx》拷贝完毕"
echo

# 遍历及处理前端文件
log "遍历并处理前端文件"
if [ -d "$base_dir/Frontend" ]; then
    for frontend_group_dir in $base_dir/Frontend/*; do
    
      log "处理前端文件夹 $(get_rel_path $frontend_group_dir)"
      
      if [ -d "$frontend_group_dir" ]; then
        frontend_group_dir_nm=$(basename "$frontend_group_dir")
        log "开始处理 ${frontend_group_dir_nm} 前端文件"
    
        # 检查目录下是否有zip文件
        zip_count=$(find "$frontend_group_dir" -name "*.zip" 2>/dev/null | wc -l)
        if [ $zip_count -eq 0 ]; then
          log "在 $(get_rel_path $frontend_group_dir) 目录中没有找到任何zip文件，无需处理。"
        else
          log "在 $(get_rel_path $frontend_group_dir) 目录中找到 $zip_count 个zip文件"
    
          # 生成lst文件
          generate_lst_script "$frontend_group_dir"
    
          # 打包前端文件
          log "开始打包前端文件"
          pkg_frontend "$frontend_group_dir_nm"
    	  
    	  # 前端发版操作手册补充
    	  generate_front_deploy_file "$frontend_group_dir_nm"
        fi
    
      fi
      
      log "前端文件夹 $(get_rel_path $frontend_group_dir) 处理完毕"
    done
    
    # 前端发版文件补充回退步骤
    deploy_file_path="$base_dir/Frontend/新信贷-前端发版步骤-$current_time.txt"
    printf "\n" >> "$deploy_file_path"
    printf "\n" >> "$deploy_file_path"
    printf "#=========================================================\n" >> "$deploy_file_path"
    printf "## 回退命令（注意：发版异常时执行）\n" >> "$deploy_file_path"
    printf "# cd /home/yw/update/deploy-script && ls -lrt\n" >> "$frontend_dir/$deploy_file_name"
    printf "\n" >> "$deploy_file_path"
    printf "# sh ECMS-WEB-ROLLBACK.sh $current_time\n" >> "$deploy_file_path"
    printf "\n" >> "$deploy_file_path"
    printf "# 若提示replace...[y]es, [n]o, [A]ll, [N]one, [r]ename:...，键入[A]即可\n" >> "$deploy_file_path"
    printf "\n" >> "$deploy_file_path"
    printf "# cd /home/yw/nginx-1.28.0/sbin && ls -lrt\n" >> "$deploy_file_path"
    printf "# ./nginx -s reload\n" >> "$deploy_file_path"
    printf "\n" >> "$deploy_file_path"
    printf "# ps -ef | grep nginx\n" >> "$deploy_file_path"
    printf "\n" >> "$deploy_file_path"
else
    log "前端文件不存在，无需处理"
fi


# 生成发版文件清单
generate_deploy_file_list

log "将文件清单复制到版本目录下"
cp "$base_dir/$deploy_file_list" ./
log "文件清单复制完成"
echo

# 压缩打包处理文件夹
if [ -f ./$deploy_dir_name.zip ]; then
  log "文件./$deploy_dir_name.zip存在，先删除文件"
  rm -rf "./$deploy_dir_name.zip"
  log "文件./$deploy_dir_name.zip，删除完毕"
  echo
fi

log "开始压缩发布包 ./$temp_dir"
compress_pkg "./$temp_dir" "./$deploy_dir_name.zip"
log "发布包 ./$deploy_dir_name.zip 压缩完成"
echo

# 删除打包处理文件夹
log "删除打包处理文件夹 $(get_rel_path $base_dir)"
rm -rf "$base_dir"
echo

# 结束时间
deploy_pkg_end_time=$(date +%s)
# 总消耗时间
deploy_pkg_cost_time=$((deploy_pkg_end_time - deploy_pkg_start_time))

log "**********************************************"
log "*******版本$deploy_dir_name发布包处理完成********"
log "********开始时间：$(date -d @$deploy_pkg_start_time '+%Y-%m-%d %H:%M:%S')*********"
log "********结束时间：$(date -d @$deploy_pkg_end_time '+%Y-%m-%d %H:%M:%S')*********"
log "*****************总耗时：${deploy_pkg_cost_time}秒*****************"
log "**********************************************"

# =====================任务脚本=====================

EOF

    # 给generate_deploy_pkg.sh脚本添加执行权限
    chmod +x "$target_dir/generate_deploy_pkg.sh"
    
    echo "   - $target_dir/generate_deploy_pkg.sh 已创建"
}

# 在根目录中创建正在创建generate_deploy_pkg.sh脚本
echo "正在创建generate_deploy_pkg.sh脚本..."

create_deploy_generate_script "$root_dir"

echo "generate_deploy_pkg.sh 脚本已创建并添加执行权限"

# 输出创建结果
echo -e "\n目录结构创建完成："
echo "$root_dir/"
echo "├── Backend/"
echo "├── Frontend/"
echo "│   ├── FK/"
echo "│   ├── H5/"
echo "│   └── WEB/"
echo "├── Database/"
echo "│   ├── ecms_astprsrvt_资产保全数据库/"
echo "│   ├── ecms_collateral_押品管理数据库/"
echo "│   ├── ecms_credit_control_额度管理数据库/"
echo "│   ├── ecms_credit_信贷业务数据库/"
echo "│   ├── ecms_distributed_分布式事务数据库/"
echo "│   ├── ecms_edoc_电子档案数据库/"
echo "│   ├── ecms_external_data_外数处理数据库/"
echo "│   ├── ecms_ipc_天元运行态数据库/"
echo "│   ├── ecms_nacos_注册配置中心数据库/"
echo "│   ├── ecms_qa_智能问答数据库/"
echo "│   ├── ecms_rms_dc_决策中心数据库/"
echo "│   ├── ecms_rms_mc_模型中心数据库/"
echo "│   ├── ecms_rule_规则引擎数据库/"
echo "│   ├── ecms_sentinel_熔断限流数据库/"
echo "│   ├── ecms_topconfig_天元网关数据库/"
echo "│   ├── ecms_workflow_流程引擎数据库/"
echo "│   └── ecms_xxl_job_批量调度数据库/"
echo "└── EdocFile/"

echo -e "\n操作步骤："
echo "1. 根据需要后端jar、md5文件复制到以下目录："
echo "   - $root_dir/Backend/   (用于后端项目部署)"
echo ""
echo "2. 根据需要将新信贷各数据库脚本复制到以下目录的对应数据库文件夹中："
echo "   - $root_dir/Database/   (数据库脚本执行)"
echo ""
echo "3. 根据需要将电子文档模板及模板替换操作手册（由电子文档组开发提供）复制到以下目录："
echo "   - $root_dir/EdocFile/   (电子文档更新)"
echo ""
echo "4. 根据需要将项目zip文件复制到以下目录："
echo "   - $root_dir/Frontend/WEB/   (用于WEB前端项目部署)"
echo "   - $root_dir/Frontend/H5/    (用于H5前端项目部署)"
echo "   - $root_dir/Frontend/FK/   (用于FK前端项目部署)"
echo ""
echo "5. 根据项目类型进入相应目录："
echo "   - cd $root_dir/  (发布版本打包)"
echo ""
echo "6. 运行 ./generate_deploy_pkg.sh 生成 版本发布包 文件"

echo -e "\n显示创建的目录和文件："
find "$root_dir" -type d | sort
echo ""
find "$root_dir" -type f | sort

echo -e "\n生成的目录名: $root_dir"