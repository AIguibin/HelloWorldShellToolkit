Private Sub CommandButton1_Click()

    Dim sql As String
    Dim tableName As String
    Dim tableChainName As String
    Dim comm As String
    Dim SEQStr As String
    Dim pkString As String '物理主键字符拼接
    Dim pk As String
    Dim pk_ As String
    Dim deleSTr As String
    Dim defaultStr As String
    Dim default As String
    
    
    
    For si = 3 To Workbooks(1).Sheets.Count
    
        Set mysheet = Workbooks(1).Sheets(si) '表
        tableName = mysheet.Range("B2").Value '表名
        tableChainName = mysheet.Range("B1").Value '表名
         
        sql = sql & vbCrLf
        
        sql = sql & "------------------- START 生成建 " & tableName & "(" & tableChainName & ") ------------------- " & vbCrLf
        
        deleSTr = deleSTr & "Drop table " & tableName & ";" & vbCrLf
        
        sql = sql & "create table  " & tableName & "(" & vbCrLf
        
        comm = ""
        
        'SEQStr = ""
        
        pk = ""
        
        defaultStr = ""
        
        For i = 4 To mysheet.UsedRange.Rows.Count
            Dim nameStr As String
            Dim nameEngStr As String
            Dim typeStr As String
            Dim lengStr As String '数据长度
            Dim keyStr As String '是否主键
            Dim nullStr As String '是否为空
            Dim wuliStr As String '是否物理组件
            Dim morenzhiStr As String '默认值
            
            
            nameStr = mysheet.Range("B" & i).Value '字段名
            nameEngStr = mysheet.Range("C" & i).Value '字段名
            typeStr = mysheet.Range("D" & i).Value '类型
            lengStr = mysheet.Range("E" & i).Value '长度
            keyStr = mysheet.Range("F" & i).Value '
            nullStr = mysheet.Range("G" & i).Value '
            wuliStr = mysheet.Range("J" & i).Value '
            morenzhiStr = mysheet.Range("H" & i).Value
            
            'If Len(nameStr) <= 0 Then
             '   continue
            'End If
            
            If Len(lengStr) > 0 Then
                typeStr = typeStr & "(" & lengStr & ")"
            End If
            
            
            If keyStr = "是" Then
            
                sql = sql & " " & nameEngStr & " " & typeStr & " NOT NULL"
                
                If Len(pk) > 0 Then
                        pk = pk & "," & nameEngStr
                    Else
                        pk = nameEngStr
                End If
                
            Else
                sql = sql & " " & nameEngStr & " " & typeStr
            End If
                
            If nullStr = "否" And keyStr = "否" And Len(lengStr) > 0 Then
                sql = sql & "NOT NULL"
            End If
            
            If i < mysheet.UsedRange.Rows.Count Then
                sql = sql & ","
            End If
            
            If wuliStr = "物理主键" Then
                SEQStr = SEQStr & vbCrLf & "CREATE SEQUENCE " & nameEngStr & " MINVALUE 1000000001 NOMAXVALUE INCREMENT BY 1 START WITH 1000000001 NOCACHE;"
            End If
            
            If Len(morenzhiStr) > 0 Then
               defaultStr = defaultStr & vbCrLf & "ALTER TABLE " & tableName & "  modify (" & nameEngStr & "  " & typeStr & " default '" & morenzhiStr & "'"
               If nullStr = "否" And keyStr = "否" And Len(lengStr) > 0 Then
                defaultStr = defaultStr & "NOT NULL"
               End If
                defaultStr = defaultStr & "); "
            End If
        
            
            comm = comm & vbCrLf & "comment on column " & tableName & "." & nameEngStr & " is '" & nameStr & "';"
            'alter table MEFP_HKSQLS add constraint pk_HKSQLS primary key(jyrq,lsh);
            
            pk_ = Replace(tableName, "MEFP", "PK")
            
          
            
             sql = sql & vbCrLf
        Next i
       sql = sql & ") tablespace MSFF_DATA;"
       
       sql = sql & comm & vbCrLf
       
       pkString = pkString & "alter table " & tableName & " add constraint " & pk_ & " primary key(" & pk & ");" & vbCrLf
       
       If Len(defaultStr) > 0 Then
        default = default & defaultStr & vbCrLf
       End If
       
       '------------------- Start 生成建 流程任务信息() -------------
       sql = sql & "------------------- END 生成建 " & tableName & "(" & tableChainName & ") ------------------- " & vbCrLf
       Next si
       
       
        deleSTr = "------------------- start 生成删除SQL start ------------------- " & vbCrLf & deleSTr
        
        sql = deleSTr & "------------------- end 生成删除SQL end ------------------- " & vbCrLf & sql & vbCrLf
        
        sql = sql & vbCrLf
        
        sql = sql & "------------------- start 生成PK start ------------------- " & vbCrLf
         
        sql = sql & pkString
        
        sql = sql & "------------------- end 生成PK end ------------------- " & vbCrLf
        
        sql = sql & vbCrLf
       
        sql = sql & "------------------- start 生成SEQUENCE start ------------------- "
         
        sql = sql & SEQStr & vbCrLf
        
        sql = sql & "------------------- end 生成SEQUENCE end ------------------- " & vbCrLf
        
        
        sql = sql & vbCrLf
       
        sql = sql & "------------------- start 生成默认值 start ------------------- "
         
        sql = sql & default & vbCrLf
        
        sql = sql & "------------------- end 生成默认值 end ------------------- " & vbCrLf
        
        
       TextBox1.Value = sql
End Sub




