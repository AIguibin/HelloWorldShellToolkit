#!/bin/bash

# 使用说明
# 将该脚本保存为 interface_test.sh
# 给脚本添加执行权限：chmod +x interface_test.sh
# 执行脚本：./interface_test.sh


# 日志文件路径
LOG_FILE="/home/yw/logs/interface.log"

# 创建日志目录
mkdir -p /home/yw/logs

# 清空或创建日志文件
> "$LOG_FILE"

# 函数：执行HTTP接口测试并记录日志
execute_http_test() {
    local system_name="$1"
    local description="$2"
    local url="$3"
    local data="$4"
    
    echo "关联系统：$system_name" | tee -a "$LOG_FILE"
    echo "接口说明：$description" | tee -a "$LOG_FILE"
    echo "接口url：$url" | tee -a "$LOG_FILE"
    echo "接口参数：$data" | tee -a "$LOG_FILE"
    
    # 执行curl请求
    response=$(curl -X POST "$url" \
        -H 'Content-Type: application/json' \
        -H 'REQUEST_ID: CREDIT' \
        -d "$data" \
        -s -w "\nHTTP状态码: %{http_code}")
    
    # 分离HTTP状态码和响应内容
    local http_code
    http_code=$(echo "$response" | awk '/HTTP状态码:/ {print $NF}')
    local response_body
    response_body=$(echo "$response" | sed '/HTTP状态码/d')
    
    echo "返回状态码：$http_code" | tee -a "$LOG_FILE"
    echo "返回结果：$response_body" | tee -a "$LOG_FILE"
    echo "----------------------------------------" | tee -a "$LOG_FILE"
    
    # 添加短暂延迟，避免请求过于频繁
    sleep 1
}

# 函数：执行Telnet端口测试并记录日志
execute_telnet_test() {
    local system_name="$1"
    local description="$2"
    local host="$3"
    local port="$4"
    
    echo "关联系统：$system_name" | tee -a "$LOG_FILE"
    echo "接口说明：$description" | tee -a "$LOG_FILE"
    echo "测试主机：$host" | tee -a "$LOG_FILE"
    echo "测试端口：$port" | tee -a "$LOG_FILE"
    echo "接口参数：telnet $host $port" | tee -a "$LOG_FILE"
    
    # 执行telnet测试
    timeout 5 telnet $host $port 2>&1 | tee -a "$LOG_FILE"
    
    # 检查telnet命令的退出状态
    telnet_exit_code=${PIPESTATUS[0]}
    if [ $telnet_exit_code -eq 0 ]; then
        echo "返回状态码：连接成功" | tee -a "$LOG_FILE"
    else
        echo "返回状态码：连接失败" | tee -a "$LOG_FILE"
    fi
    
    echo "----------------------------------------" | tee -a "$LOG_FILE"
    
    # 添加短暂延迟
    sleep 1
}

# 函数：执行MySQL查询测试
execute_mysql_test() {
    local system_name="$1"
    local description="$2"
    local host="$3"
    local port="$4"
    local user="$5"
    local password="$6"
    local database="$7"
    local query="$8"
    
    echo "关联系统：$system_name" | tee -a "$LOG_FILE"
    echo "接口说明：$description" | tee -a "$LOG_FILE"
    echo "测试主机：$host" | tee -a "$LOG_FILE"
    echo "测试端口：$port" | tee -a "$LOG_FILE"
    echo "数据库：$database" | tee -a "$LOG_FILE"
    echo "查询语句：$query" | tee -a "$LOG_FILE"
    
    # 执行MySQL查询
    result=$(mysql -h $host -P $port -u $user -p$password -D $database -e "$query" 2>&1)
    mysql_exit_code=$?
    
    echo "返回状态码：$mysql_exit_code" | tee -a "$LOG_FILE"
    echo "返回结果：$result" | tee -a "$LOG_FILE"
    echo "----------------------------------------" | tee -a "$LOG_FILE"
    
    # 添加短暂延迟
    sleep 1
}

# 主执行逻辑
main() {
    echo "开始执行接口测试..." | tee -a "$LOG_FILE"
    echo "开始时间: $(date)" | tee -a "$LOG_FILE"
    echo "----------------------------------------" | tee -a "$LOG_FILE"
    
    # 接口1: 核心系统 - 贷款账户详细信息查询
    execute_http_test "核心系统" "贷款账户详细信息查询 (0104001)" \
        "http://tianygw-a-b.ecms.cscloud.hnrcc.bank:10002/ty-gateway/ty-api/ecms" \
        '{"ServiceCode":"CBS0104001","ServiceScene":"1","ConsumerId":"205012","OrgConsumerId":"1","ConsumerSeqNo":"1","OrgConsumerSeqNo":"1","TranDate":"1","TranTime":"1","TranTellerNo":"1","TranBranchId":"1","BODY":{"LoanAcctNo":"1","UUID":"1"}}'
    
    # 接口2: 客户信息管理系统 - 对公客户基本信息查询
    execute_http_test "客户信息管理系统" "对公客户基本信息查询 (ECIF120)" \
        "http://tianygw-a-b.ecms.cscloud.hnrcc.bank:10002/ty-gateway/ty-api/ecms" \
        '{"ServiceCode":"ECIF120","ServiceScene":"1","ConsumerId":"205012","OrgConsumerId":"1","ConsumerSeqNo":"1","OrgConsumerSeqNo":"1","TranDate":"1","TranTime":"1","TranTellerNo":"1","TranBranchId":"1","BODY":{"ECIFCstNo":"1","PrygCtrlUp":"","PrygCtrlCd":""}}'
    
    # 接口3: 电子签章 - 根据企业或部门ID查询印章
    execute_http_test "电子签章系统" "根据企业或部门ID查询印章 (6030110005)" \
        "http://tianygw-a-b.ecms.cscloud.hnrcc.bank:10002/ty-gateway/ty-api/ecms" \
        '{"ServiceCode":"CA6030110005","ServiceScene":"1","ConsumerId":"205012","OrgConsumerId":"1","ConsumerSeqNo":"1","OrgConsumerSeqNo":"1","TranDate":"1","TranTime":"1","TranTellerNo":"1","TranBranchId":"1","BODY":{"TokenInf":"1","EntpId":"1"}}'
    
    # 接口4: 票据系统 - 法人行利率查询
    execute_http_test "票据系统" "法人行利率查询 (XD004)" \
        "http://tianygw-a-b.ecms.cscloud.hnrcc.bank:10002/ty-gateway/ty-api/ecms" \
        '{"ServiceCode":"XD004","ServiceScene":"1","ConsumerId":"205012","OrgConsumerId":"1","ConsumerSeqNo":"1","OrgConsumerSeqNo":"1","TranDate":"1","TranTime":"1","TranTellerNo":"1","TranBranchId":"1","BODY":{"AcptBnkBrId":"1","DmdInd":"1","TermUnit":"1","TxnCd":"1","CnlTp":"1"}}'
    
    # 接口5: 二代支付系统 - 跨行转账交易信息查询
    execute_http_test "二代支付系统" "跨行转账交易信息查询 (1400210110)" \
        "http://tianygw-a-b.ecms.cscloud.hnrcc.bank:10002/ty-gateway/ty-api/ecms" \
        '{"ServiceCode":"TGPS1400210110","ServiceScene":"1","ConsumerId":"205012","OrgConsumerId":"1","ConsumerSeqNo":"1","OrgConsumerSeqNo":"1","TranDate":"1","TranTime":"1","TranTellerNo":"1","TranBranchId":"1","BODY":{"TfrCnlTp":"01","OrigTxnDt":"1","OrigCnlSeqNo":"1","OrigCnlSysIDNo":"1"}}'
    
    # 接口6: 信贷业务整合 - 便民卡本利回收交易
    execute_http_test "信贷业务整合系统" "便民卡本利回收交易 (500300010)" \
        "http://tianygw-a-b.ecms.cscloud.hnrcc.bank:10002/ty-gateway/ty-api/ecms" \
        '{"ServiceCode":"CBI000500300010","ServiceScene":"1","ConsumerId":"205012","OrgConsumerId":"1","ConsumerSeqNo":"1","OrgConsumerSeqNo":"1","TranDate":"1","TranTime":"1","TranTellerNo":"1","TranBranchId":"1","BODY":{"CardNo":"1","TxnAmt":1000.08,"LoanAcctNolistInf":"1","RepyAcctNo":"1","EffClsInd":"1","RepyTp":"1","CardTp":"1","RdCardInd":"1","TwoTrackInf":"","ThreeTrackInf":",","PwdVerfInd":"1","PwdTp":",","EncptnPwd":",","HChnCode":null}}'
    
    # 接口7: 省农担前置 - 银行推送申请查询项目进度结果
    execute_http_test "省农担前置系统" "银行推送申请查询项目进度结果 (1000011003)" \
        "http://tianygw-a-b.ecms.cscloud.hnrcc.bank:10002/ty-gateway/ty-api/ecms" \
        '{"ServiceCode": "CLFJR001000011003","ServiceScene": "1","ConsumerId": "205012","OrgConsumerId": "1","ConsumerSeqNo": "1","OrgConsumerSeqNo": "1","TranDate": "1","TranTime": "1","TranTellerNo": "1","TranBranchId": "1","BODY": {"AplySeqNo": "1","PrjId": "1","EnqrTp": "1","ServiceTranCode": "001000011003"}}'
    
    # 接口8: 国结系统 – 币种汇率查询
    execute_http_test "国结系统" "币种汇率查询 (999998)" \
        "http://tianygw-a-b.ecms.cscloud.hnrcc.bank:10002/ty-gateway/ty-api/ecms" \
        '{"ServiceCode":"ISS999998","ServiceScene":"1","ConsumerId":"205012","OrgConsumerId":"1","ConsumerSeqNo":"1","OrgConsumerSeqNo":"1","TranDate":"1","TranTime":"1","TranTellerNo":"1","TranBranchId":"1","BODY":{"Ccy":"1","CshRmtTp":"1"}}'
    
    # 接口9: 股权及关联交易管理系统 – 股东信息查询
    execute_http_test "股权及关联交易管理系统" "股东信息查询 (1200300001063)" \
        "http://tianygw-a-b.ecms.cscloud.hnrcc.bank:10002/ty-gateway/ty-api/ecms" \
        '{"ServiceCode":"TSQGLJY1200300001063","ServiceScene":"1","ConsumerId":"205012","OrgConsumerId":"1","ConsumerSeqNo":"1","OrgConsumerSeqNo":"1","TranDate":"1","TranTime":"1","TranTellerNo":"1","TranBranchId":"1","BODY":{"BrId":"1","BrNm":"1","CstNm":"1","CstIdentTp":"1","CstIdentNo":"1"}}'
    
    # 接口10: 内联网关 – 身份认证三要素接口
    execute_http_test "内联网关" "身份认证三要素接口 (6030010003)" \
        "http://tianygw-a-b.ecms.cscloud.hnrcc.bank:10002/ty-gateway/ty-api/ecms" \
        '{"ServiceCode":"IG6030010003","ServiceScene":"1","ConsumerId":"205012","OrgConsumerId":"1","ConsumerSeqNo":"1","OrgConsumerSeqNo":"1","TranDate":"1","TranTime":"1","TranTellerNo":"1","TranBranchId":"1","BODY":{"CnlNo":"1","LglNmBankNo":"1","CnlCd":"1","IdntChckTp":"1","Name":"1","IdentNo":"1","IdntNoffftDtTp":"","Begot":"","CrdPhoto":"1","OprlPolcyTp":"1"}}'
    
    # 接口11: 企业信息联网核查 - 手机号码联网核查
    execute_http_test "企业信息联网核查系统" "手机号码联网核查 (QYHC0001)" \
        "http://tianygw-a-b.ecms.cscloud.hnrcc.bank:10002/ty-gateway/ty-api/ecms" \
        '{"ServiceCode":"QYHC0001","ServiceScene":"1","ConsumerId":"205012","OrgConsumerId":"1","ConsumerSeqNo":"1","OrgConsumerSeqNo":"1","TranDate":"1","TranTime":"1","TranTellerNo":"1","TranBranchId":"1","BODY":{"CnNo":"1","CnLc4":"1","IdntChckTp":"1","Begot":"","CrdPhoto":""}}'
    
    # 接口12: 存量房网签接入 - 查询网签交易数据
    execute_http_test "存量房网签系统" "查询网签交易数据 (1000010001)" \
        "http://tianygw-a-b.ecms.cscloud.hnrcc.bank:10002/ty-gateway/ty-api/ecms" \
        '{"ServiceCode":"CLFJR001000010001","ServiceScene":"1","ConsumerId":"205012","OrgConsumerId":"1","ConsumerSeqNo":"1","OrgConsumerSeqNo":"1","TranDate":"1","TranTime":"1","TranTellerNo":"1","TranBranchId":"1","BODY":{"BnkOnlyInd":"1","SignCtrNo":"1","ServiceTranCode":"1"}}'
    
    # 接口13: 资金业务系统 - 企业客户授信结果通知
    execute_http_test "资金业务系统" "企业客户授信结果通知 (1200300001062)" \
        "http://tianygw-a-b.ecms.cscloud.hnrcc.bank:10002/ty-gateway/ty-api/ecms" \
        '{"ServiceCode":"ZJGLXT1200300001062","ServiceScene":"1","ConsumerId":"205012","OrgConsumerId":"1","ConsumerSeqNo":"1","OrgConsumerSeqNo":"1","TranDate":"1","TranTime":"1","TranTellerNo":"1","TranBranchId":"1","BODY":{"BrId":"1","SocCrCd":"1","IvsLmt":"1","CrGrntStrtDt":"1","CrGrntExpDt":"1","RvlvInd":"1","LmtTpCd":"1"}}'
    
    # 接口14: 智能双录 – 申请双录流水
    execute_http_test "智能双录系统" "双录结果查询 (0800300000401)" \
        "http://tianygw-a-b.ecms.cscloud.hnrcc.bank:10002/ty-gateway/ty-api/ecms" \
        '{"BODY":{"TxnCd":"1","BnkSchNo":"1"},"ServiceCode":"SLXT0800300000401","ServiceScene":"1","ConsumerId":"205012","OrgConsumerId":"1","ConsumerSeqNo":"1","OrgConsumerSeqNo":"1","TranDate":"1","TranTime":"1","TranTellerNo":"1","TranBranchId":"1"}'
    
    # 接口15: 财务管理系统 – 职工信息实时查询接口
    execute_http_test "财务管理系统" "职工信息实时查询接口 (ZG0001)" \
        "http://tianygw-a-b.ecms.cscloud.hnrcc.bank:10002/ty-gateway/ty-api/ecms" \
        '{"ServiceCode":"ZG0001","ServiceScene":"1","ConsumerId":"205012","OrgConsumerId":"1","ConsumerSeqNo":"1","OrgConsumerSeqNo":"1","TranDate":"1","TranTime":"1","TranTellerNo":"1","TranBranchId":"1","BODY":{"IdentNo":"1","EmpeNm":"1"}}'
    
    # 接口16: 征信因子解析工具 - 征信指标结果查询
    execute_http_test "征信因子解析工具" "征信指标结果查询 (zjjg0002)" \
        "http://tianygw-a-b.ecms.cscloud.hnrcc.bank:10002/ty-gateway/ty-api/ecms" \
        '{"ServiceCode":"FXYDzjjg0002","ServiceScene":"1","ConsumerId":"205012","OrgConsumerId":"1","ConsumerSeqNo":"1","OrgConsumerSeqNo":"1","TranDate":"1","TranTime":"1","TranTellerNo":"1","TranBranchId":"1","BODY":{"CnlCd":"1","AplySeqNo":"1","Rslt0ryCd":"1","IPAdr":"1"}}'
    
    # 接口17: 名单监测管理系统 - 名单实时查验
    execute_http_test "名单监测管理系统" "名单实时查验 (1)" \
        "http://tianygw-a-b.ecms.cscloud.hnrcc.bank:10002/ty-gateway/ty-api/ecms" \
        '{"ServiceCode":"LMMS01","ServiceScene":"1","ConsumerId":"205012","OrgConsumerId":"1","ConsumerSeqNo":"1","OrgConsumerSeqNo":"1","TranDate":"1","TranTime":"1","TranTellerNo":"1","TranBranchId":"1","BODY":{"TxnTpCd":"1","TranDtTm":"1","RqsInfArry":[{"SrlNo":"1","SpcllistTp":null,"CstInfStrct":{"CstIdentTp":"1","CstIdentNo":"1","CstNm":"1","CstCardNo":"1","CstNatCd":null,"CstCtcTelNo":null},"AcctNoInfStrct":{}}]}}'
    
    # 接口18: 内部资金转移定价系统 - 资金成本率查询
    execute_http_test "内部资金转移定价系统" "资金成本率查询 (0200300000526)" \
        "http://tianygw-a-b.ecms.cscloud.hnrcc.bank:10002/ty-gateway/ty-api/ecms" \
        '{"BODY":{"LglNo":"1","PdNo":"1","CtrAmt":"1","LoanRng":"1","RateTp":"1","RepyMth":"1","UUID":null},"ServiceCode":"02003000005","ServiceScene":"1","ConsumerId":"205012","OrgConsumerId":"1","ConsumerSeqNo":"1","OrgConsumerSeqNo":"1","TranDate":"1","TranTime":"1","TranTellerNo":"1","TranBranchId":"1"}'
    
    # 接口19: 生物特征识别平台 - 人脸1:1
    execute_http_test "生物特征识别平台" "人脸1:1 (BIAP0008)" \
        "http://tianygw-a-b.ecms.cscloud.hnrcc.bank:10002/ty-gateway/ty-api/ecms" \
        '{"ServiceCode":"BIAP0008","ServiceScene":"1","ConsumerId":"205012","OrgConsumerId":"1","ConsumerSeqNo":"1","OrgConsumerSeqNo":"1","TranDate":"1", "TranTime":"1","TranTellerNo":"1","TranBranchId":"1","BODY":{"MnfctrId":"1","CstPltfmId":"1","ServiceTranCode":"1","AgmtVersNo":"1","OrgConsumerTm":"1","MsgTp":"1","MapItBranchId":"1","OrgConsumerEntpId":"1","OrgConsumerChnITp":"1","TxnPrsnId":"1","MbtTp":null,"OprtngSystmTp":null,"OprtngSystmVersNo":null,"IMEI":null,"MEID":null,"SeqNo":null,"LgtNum":null,"LttNum":null,"ctyCd":null,"ProvCd":null,"CityCd":null,"CityCd":null,"TxnAmt":null,"MtlTrstCd":null,"AhrCd":null,"FtrVal":"","ImgDataInf":""}}'
    
    # 接口20: 二代征信业务管理系统 - 中征码本地数据查询接口
    execute_http_test "二代征信业务管理系统" "中征码本地数据查询接口 (QP1008)" \
        "http://tianygw-a-b.ecms.cscloud.hnrcc.bank:10002/ty-gateway/ty-api/ecms" \
        '{"ServiceCode":"QP1008","ServiceScene":"1","ConsumerId":"205012","OrgConsumerId":"1","ConsumerSeqNo":"1","OrgConsumerSeqNo":"1","TranDate":"1","TranTime":"1","TranTellerNo":"1","TranBranchId":"1","BODY":{"TxnCd":"QP1008","ReqSysNo":"1","RltvEntpNm":"1","IdentTp":"1","IdentNo":"1","UsrNo":"1","BsnBrId":"1","LclInd":"1"}}'
    
    # 接口21: 人力资源系统 - 人员信息查询
    execute_http_test "人力资源系统" "人员信息查询 (HR0002)" \
        "http://tianygw-a-b.ecms.cscloud.hnrcc.bank:10002/ty-gateway/ty-api/ecms" \
        '{"ServiceCode":"HR0002","ServiceScene":"1","ConsumerId":"205012","OrgConsumerId":"1","ConsumerSeqNo":"1","OrgConsumerSeqNo":"1","TranDate":"1","TranTime":"1","TranTellerNo":"1","TranBranchId":"1","BODY":{"Name":"1","IdentNo":"1"}}'
    
    # 接口22: 身份核查系统 - 单笔身份信息核对
    execute_http_test "身份核查系统" "单笔身份信息核对 (SFHC0001)" \
        "http://tianygw-a-b.ecms.cscloud.hnrcc.bank:10002/ty-gateway/ty-api/ecms" \
        '{"ServiceCode":"SFHC0001","ServiceScene":"1","ConsumerId":"205012","OrgConsumerId":"1","ConsumerSeqNo":"1","OrgConsumerSeqNo":"1","TranDate":"1","TranTime":"1","TranTellerNo":"1","TranBranchId":"1","BODY":{"BVrty":"1","IdentNo":"1","CstNm":"1","RetImgInd":"1","ChkInd":"1","IdentTp":null}}'
    
    # 接口23: 消息平台 - 单笔短信发送
    execute_http_test "消息平台" "单笔短信发送 (6030080013)" \
        "http://tianygw-a-b.ecms.cscloud.hnrcc.bank:10002/ty-gateway/ty-api/ecms" \
        '{"ServiceCode":"TCDXPT6030080013","ServiceScene":"1","ConsumerId":"205012","OrgConsumerId":"1","ConsumerSeqNo":"1","OrgConsumerSeqNo":"1","TranDate":"1","TranTime":"1","TranTellerNo":"1","TranBranchId":"1","BODY":{"VerfInf":"1","SgnInf":"1","BatchNo":null,"BtchNm":null,"TplNo":"1","RcvrInf":"[\"1\"]","NewsTp":"1","MsgCntntInf":"1","PblcArgInf":null,"ShdTm":null,"ExtInf":null,"PrvtArgInf":null,"MnpltTellerNo":null,"InstCdInf":"{\"1\":\"1\"}","UUID":null}}'
    
    # 接口24: 短信前置 - 短信分发动账推送白名单维护
    execute_http_test "短信前置系统" "短信分发动账推送白名单维护 (500610032)" \
        "http://tianygw-a-b.ecms.cscloud.hnrcc.bank:10002/ty-gateway/ty-api/ecms" \
        '{"BODY":{"MnpltTp":"1","SignAcctNo":"1","CstNm":"1","SysNo":"1","OrigCnlCd":"1","BsnScene":"1","SndMsgInd":"1","ServiceTranCode":"1"},"ServiceCode":"FBUSS000500610032","ServiceScene":"1","ConsumerId":"205012","OrgConsumerId":"1","ConsumerSeqNo":"1","OrgConsumerSeqNo":"1","TranDate":"1","TranTime":"1","TranTellerNo":"1","TranBranchId":"1","HChnlCode":null}'
    
    # 接口25: 智能应用 - 外国人永久居住证 (Telnet测试)
    execute_telnet_test "智能应用系统" "外国人永久居住证端口连通性测试" "10.1.1.150" "8080"
    
    # 接口26: 银行流水分析平台 - 用户登录
    execute_http_test "银行流水分析平台" "用户登录 (6030130001)" \
        "http://tianygw-a-b.ecms.cscloud.hnrcc.bank:10002/ty-gateway/ty-api/ecms" \
        '{"ServiceCode":"IG6030130001","ServiceScene":"1","ConsumerId":"205012","OrgConsumerId":"1","ConsumerSeqNo":"1","OrgConsumerSeqNo":"1","TranDate":"1","TranTime":"1","TranTellerNo":"1","TranBranchId":"1","BODY":{"UsrNm":"1","Pwd":"1","StmtcIndNo":"1"}}'
    
    # 接口27: 电子渠道 - 账户加挂查询
    execute_http_test "电子渠道系统" "账户加挂查询 (6010010004)" \
        "http://tianygw-a-b.ecms.cscloud.hnrcc.bank:10002/ty-gateway/ty-api/ecms" \
        '{"ServiceCode":"IG6010010004","ServiceScene":"1","ConsumerId":"205012","OrgConsumerId":"1","ConsumerSeqNo":"1","OrgConsumerSeqNo":"1","TranDate":"1","TranTime":"1","TranTellerNo":"1","TranBranchId":"1","BODY":{"IdentTp":"1","IdentNum":"1","Mb1No":"1","TxnCntTp":"1"}}'
    
    # 接口28: 企业网银 - 贷款申请信息查询
    execute_http_test "企业网银系统" "贷款申请信息查询 (6010020004)" \
        "http://tianygw-a-b.ecms.cscloud.hnrcc.bank:10002/ty-gateway/ty-api/ecms" \
        '{"BODY":{"CustNo":"1","ApiApiyId":"1","UUID":null},"ServiceCode":"IG6010020004","ServiceScene":"1","ConsumerId":"205012","OrgConsumerId":"1","ConsumerSeqNo":"1","OrgConsumerSeqNo":"1","TranDate":"1","TranTime":"1","TranTellerNo":"1","TranBranchId":"1"}'
    
    # 接口29: 微信银行 - 根据微信用户凭证查询用户信息
    execute_http_test "微信银行系统" "根据微信用户凭证查询用户信息 (6010010037)" \
        "http://tianygw-a-b.ecms.cscloud.hnrcc.bank:10002/ty-gateway/ty-api/ecms" \
        '{"ServiceCode":"IG6010010037","ServiceScene":"1","ConsumerId":"205012","OrgConsumerId":"1","ConsumerSeqNo":"1","OrgConsumerSeqNo":"1","TranDate":"1","TranTime":"1","TranTellerNo":"1","TranBranchId":"1","BODY":{"WeiXinNo":"1"}}'
    
    # 接口30: 财务报表识别平台 - 获取Token
    execute_http_test "财务报表识别平台" "获取Token (6030140001)" \
        "http://tianygw-a-b.ecms.cscloud.hnrcc.bank:10002/ty-gateway/ty-api/ecms" \
        '{"ServiceCode":"IG6030140001","ServiceScene":"1","ConsumerId":"205012","OrgConsumerId":"1","ConsumerSeqNo":"1","OrgConsumerSeqNo":"1","TranDate":"1","TranTime":"1","TranTellerNo":"1","TranBranchId":"1","BODY":{"UsrNo":"1","Pwd":"1"}}'
    
    # 接口31: 影像平台 - 查询阶段 (Telnet测试)
    execute_telnet_test "影像平台" "查询阶段端口连通性测试" "10.11.123.17" "8081"
    
    # 接口32: 大数据平台 - 产品风险数据查询与导出
    execute_http_test "大数据平台" "产品风险数据查询与导出 (ECMS0015)" \
        "http://tianygw-a-b.ecms.cscloud.hnrcc.bank:10002/ty-gateway/ty-api/op-api/api/biz" \
        '{"msgDt":"1","appId":"1","msgId":"1","serviceCd":"ECMS0015","appSecret":"1","version":"1","msgTm":"1","Body":{"data_dt":"","prod_no":"1","pageNum":"1","pageSize":"1"}}'
    
    # 接口33: 房产在线估值 - 用户登陆
    execute_http_test "房产在线估值系统" "用户登陆 (VQ001)" \
        "http://tianygw-a-b.ecms.cscloud.hnrcc.bank:10002/ty-gateway/ty-api/ems" \
        '{"appId":"1","uuid":"1", "signature":"1", "timestamp":"1", "body":{"userName":"1","userPwd":"1","serils":null}, "servicecode":"VQ001"}'
    
    # 接口34: 福祥E贷 - 最新婚姻状况查询
    execute_http_test "福祥E贷系统" "最新婚姻状况查询 (10050005)" \
        "http://tianygw-a-b.ecms.cscloud.hnrcc.bank:10002/ty-gateway/ty-api/ecms2/service" \
        '{"ChannelId":"1","Encrypt":null,"ExternalReference":"1","RequestBranchCode":null,"RequestOperatorId":null,"RequestTime":"1","ServiceCode":"FXYD10050005","TermNo":null,"TradeDate":"1","Uuid":null,"Version":null,"SessionId":null,"CustomerId":null,"CustomerIP":null,"DeviceId":null,"Location":null,"RequestBody":{"CallerName":"晚雅苏","CallerCard":"1","CallerPhone":"1","CallerDuty":"1","CallerWorkUnit":"1","CallReason":"1","Name":"1","IdCard":"1","Flag":"1","ValidDays":"1"}}'
    
    # 接口35: 账户流水查询平台 - 存款帐户历史金融交易明细查询
    execute_http_test "账户流水查询平台" "存款帐户历史金融交易明细查询 (490)" \
        "http://tianygw-a-b.ecms.cscloud.hnrcc.bank:10002/ty-gateway/ty-api/zhlscx-esb/api/" \
        '{"ServiceCode":"ZHLSCX000490","ServiceScene":"","ConsumerId":"205012","OrgConsumerId":"1","ConsumerSeqNo":"1","OrgConsumerSeqNo":"1","TranMode":"1","TranDate":"1","TranTime":"1","TranTellerNo":"1","TranBranchId":"1","RequestBody": {"ProvCd":"1","OldAcctNo":"","AcctNo":"1","VolNo":"","SrlNo":"","TxnStrtNo":"1","TxnStrtDt":"1","TxnExpDt":"1","acct_NoFlag":"1","PgNo":"1","PgLineNum":"1","ServiceTranCode":"1","SubAcctCd1":"","IsTotal":""}}'
    
    # 接口36: 外部数据平台 - 手机近6月内通话次数核查
    execute_http_test "外部数据平台" "手机近6月内通话次数核查 (UNXY00049)" \
        "http://tianygw-a-b.ecms.cscloud.hnrcc.bank:10002/ty-gateway/ty-api/edmp" \
        '{"SCENES_CODE":"UNXY00049","SERVICE_CODE":"UNXY00049","CONSUM_SYS_CODE":"ECMS","CONSUM_REQ_DATE":"1","CONSUM_REQ_TIME":"1","PROVID_SYS_CODE":"ECMS","LEG_ORG_ID":"1","GLOBAL_SEQ":"1","CHARACTER_SET":null,"COMM_TYPE":null,"FILE_FLAG":"1","FILE_PATH":null,"RET_CODE":null,"RET_INFO":null,"LOCAL_LANG":null,"SERVICE_REQ_SEQ":null,"CHANNEL_ID":null,"PKG_LENGTH":null,"PROVID_RSP_DATE":null,"PROVID_RSP_TIME":null,"BRANCH_ID":"90099007","PRODUCT_CODE":null,"TRAN_TELLER":null,"RequestBody":{"phoneNo":"1","crdlsTyp":"1","idfyPhoneNo":"1","crdlsNo":"1"}}'
    
    # 接口37: 在线地图 - 地址纠正补全
    execute_http_test "在线地图系统" "地址纠正补全 (TC001)" \
        "http://tianygw-a-b.ecms.cscloud.hnrcc.bank:10002/ty-gateway/ty-api/mapqq" \
        '{"address":"1","key":"1","output":1,"callback":1,"servicecode":"TC001","txnSeqNo":"1"}'
    
    # 接口38: WPS文档中台 - WPS-获取预览链接
    execute_http_test "WPS文档中台" "WPS-获取预览链接 (WpsPreviewOO1)" \
        "http://tianygw-a-b.ecms.cscloud.hnrcc.bank:10002/ty-gateway/ty-api/wps" \
        '{"WpsDocsDate":"Tue, 01 Jul 2025 07:37:51 GMT","WpsDocsAuthorization":"WPS-4 OLGNXNOLIOPJZNDX:93463982094c0bdf1bc8ea14f71ddc1bbcc0c8d8830524f402f8cf8684bd6919","file_id":"1","type":"1","_w_third_name":"","ServiceCode":"WpsPreview001"}'
    
    # 接口39: 诺税通发票验真 - 增值税发票验真
    execute_http_test "诺税通发票验真系统" "增值税发票验真 (NSTOO1)" \
        "http://tianygw-a-b.ecms.cscloud.hnrcc.bank:10002/ty-gateway/ty-api/open" \
        '{"accessToken":"1","senid":"1","nonce":"1","timestamp":"1","appkey":"1","servicecode":"NST001","XNuonuoSign":"1","Contenttype":"1","method":"1","userTax":null,"taxNo":null,"invoiceCode":null,"invoiceNo":"1","invoiceDate":"1","optionField":"1","appSecret":"1"}'
    
    
    # 接口40: 影像平台网页测试
    execute_http_test "影像平台" "API下载接口" "http://10.12.170.205:10103/channel/publicMethod/getFile/ew0KICJtb2RlbENvZGUiOiJFQ01TIiwNCiAiYnVzaW5lc3NObyI6IkNQMjAyNTAzMTEwMTUyMjYiLA0KICJmaWxlTm8iOiJCOUY0NzcxQy02MTdBLTJEMzItODZGMC1DNDE1RUQyOUY2NTMiLA0KICJidXNpRmlsZVR5cGUiOiIwMzYwMTYwMDEwMDQwMDEiDQp9eyJidXNpbmVzc05vIjoiMSIsImZpbGVObyI6IjEiLCJtb2RlbENvZGUiOiIxIiwiYnVzaUZpbGVUeXBlIjoiMSJ9/1" "" "GET"
    
    # 接口41：通过外数中心调用省农担
    execute_http_test "外数中心发送大文件至省农担" "银行推送退费申请(001000011008)" \
        "http://10.12.170.205:10122/external/interface/clfjr/send001000011008" \
        '{"acctNO":"1","acctName":"1","applAmt":"1","applNo":"1","applmemo":"1","bank":"1","borrowingEndTime":"1","brchCd":"1","fileBase":"1","fileName":"1","proId":"1"}'
    
    echo "接口测试执行完成!" | tee -a "$LOG_FILE"
    echo "结束时间: $(date)" | tee -a "$LOG_FILE"
}

# 执行主函数
main

