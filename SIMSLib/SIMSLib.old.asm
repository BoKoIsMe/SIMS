.686
.model flat, stdcall
option casemap : none

include windows.inc
include user32.inc
include kernel32.inc
include ..\SIMS\Header.inc

includelib user32.lib
includelib kernel32.lib

OPEN_FILE_FAIL                                   EQU 1000000
OPEN_FILE_ERROR_SIZE                             EQU 1000001
WRITE_FILE_FAIL                                  EQU 1000002
READ_FILE_FAIL                                   EQU 1000003
FILE_LENGTH_ILLEGAL                              EQU 1000004
CLOSE_FILE_ERROR                                 EQU 1000101
THE_FILE_HEADER_CHECKSUM_DETECTED_A_PARITY_ERROR EQU 1000201
PASSWORD_NO_MATCH                                EQU 1000202
NO_RECORD_BE_FIND                                EQU 1000203
NOT_ALLOW_CHANGE_FILE                            EQU 1000204
UNKNOW_ERROR                                     EQU 1000999
DO_NOT_SHARE                                     EQU 0
BuffLimit                                        EQU 20
InitializeFileHeader       PROTO lphFile:DWORD
CRP                        PROTO len:DWORD,lpCRCSTRING:DWORD
Read_SI_Records2LinkedList PROTO hFile:DWORD,lpLinkedListInfo:DWORD
AppendRecord               PROTO lpSIRecord:DWORD,lpLinkedListInfo:DWORD
.data
	szFileHeader SIMSDataBaseFileHeader <>
.data?
	hInstance dd ?

.const
    szErrorTitle          BYTE "错误", 0
    szErrorHeaderFileSize BYTE "文件头数据区长度非法，是否重新初始化数据库文件",0
    szErrorHeaderFileCRC  BYTE "文件头数据区无法通过循环校验，数据库遭破坏无法修复。选择“是”数据将丢失并初始化，选择“否”放弃操作文件。",0
	
.CODE

;//入口.如果DLL需要加载资源,需要保存hIinstDLL这个句柄到全局变量.它才是模块句柄
;//使用GetModuleHandle获得的永远是主程序的句柄
LibMain proc hInstDLL:DWORD, reason:DWORD, unused:DWORD
	.if reason == DLL_PROCESS_ATTACH					;//动态库被加载时调用,返回0加载失败!
		mov eax,hInstDLL
		mov hInstance,eax
		
		mov eax,TRUE
		ret
	.elseif reason == DLL_PROCESS_DETACH
		
	.elseif reason == DLL_THREAD_ATTACH
		
	.elseif reason == DLL_THREAD_DETACH
		mov eax,hInstDLL
		mov hInstance,eax
            		;//添加处理代码
        mov eax,unused
		mov eax,TRUE
		ret
	.endif
ret
LibMain Endp

;//供主程序调用的动态链接函数例子
;//MsgBox proc hWnd,lpszText,fStyle
;//	invoke MessageBox, hWnd, lpszText, offset lpszByDll, fStyle
;// ret
;// MsgBox endp

ErrorHandler PROC PRIVATE
;// 显示合适的系统错误消息
        .data
pErrorMsg DWORD ? ;// 指向错误消息的指针
messageID DWORD ?
        .code
    INVOKE GetLastError;// 在EAX中返回消息ID
    mov messageID, eax

;// 获取对应的消息字符串
    INVOKE FormatMessage, FORMAT_MESSAGE_ALLOCATE_BUFFER + FORMAT_MESSAGE_FROM_SYSTEM, NULL, messageID, NULL, ADDR pErrorMsg, NULL, NULL

;// 显示错误消息
    INVOKE MessageBox, NULL, pErrorMsg, ADDR szErrorTitle, MB_ICONERROR + MB_OK

;// 释放消息字符串
    INVOKE LocalFree, pErrorMsg
    ret
ErrorHandler ENDP

CRP proc USES esi len:DWORD,lpCRCString:DWORD
;//根据输入标的长度 对标的串做CRC校验检测并返回校验码
;//
;//输入参数:串长度 len:DWORD N位，串本体指针 lpCRCString:DWORD K位
;//返回值定义:CRC检验码 R位
    xor edx, edx
    mov ecx,len
    mov esi,lpCRCString
    L1:
    lodsb
    push ecx
    mov ecx, 8
    L2:
    test edx,08000h
    jne @F
    shl edx,1
    jmp N1
    @@:
    shl edx, 1
    xor edx,01021h
    N1:
    clc
    shl al,1
    jnc @F
    xor edx,01021h
    @@:
    loop L2
    pop  ecx
    loop L1
    mov eax,edx
    ret
CRP endp

InitializeFileHeader PROC PRIVATE USES esi edi ecx,hFile:DWORD
;//用于初始化数据库文件头，并写入文件。
;//
;//
;//输入参数:文件句柄 hFile
;//返回值定义:返回值为空 void return
    LOCAL @dwBytesWritten:DWORD
    invoke GetLocalTime,ADDR szFileHeader.DataBaseCreateTime
    lea esi,szFileHeader.DataBaseCreateTime
    lea edi,szFileHeader.DataBaseChangeTime
    mov ecx,sizeof SYSTEMTIME
    cld
    rep movsb
    mov szFileHeader.Records,0
    mov szFileHeader.RecordSize, sizeof STUDENT
    mov szFileHeader.FileChangeCount,1
    mov szFileHeader.AllowChange,TRUE
    invoke CRP, szFileHeader.FileHeaderSize,ADDR szFileHeader.DefineString
    mov szFileHeader.FileHeaderCRC,eax
    invoke SetFilePointer,hFile,0,0,FILE_BEGIN
    invoke WriteFile,hFile,ADDR szFileHeader,sizeof szFileHeader,ADDR @dwBytesWritten,NULL
    xor eax,eax
    ret
InitializeFileHeader ENDP

Read_SI_Records2LinkedList PROC PRIVATE USES edi esi ecx edx,hFile:DWORD,lpLinkedListInfo:DWORD
    LOCAL @lpFileBuf:DWORD
    LOCAL @dwNumberOfBytesRead:DWORD
    LOCAL @dwRemainingRecord:DWORD,@dwLastNode:DWORD,@dwNextNode:DWORD
;//读取学生信息记录并开辟内存用于存放记录链表
;//
;//输入参数:文件句柄 hFile ,链表信息结构指针 lpListNodeInfo
;//返回值定义:非零值为指向链表第一节的指针，为零则读取记录失败
    mov @dwLastNode,NULL
    invoke GlobalAlloc, GPTR, sizeof STUDENT * BuffLimit;//向操作系统申请内存，并为内存链表建立循环做循环前数据准备
    .if eax == FALSE
        call ErrorHandler
        xor eax,eax
        ret
    .else
        mov @lpFileBuf,eax
        mov edi, lpLinkedListInfo
        mov (LNF ptr[edi]).FirstNodeAddress, eax;//将链表首节地址装入链表维护结构体
        add eax,sizeof STUDENT
        mov @dwNextNode,eax
    .endif
    mov edx,szFileHeader.Records
    mov @dwRemainingRecord,edx
    mov edi,lpLinkedListInfo
    mov (LNF ptr [edi]).TotalNodeCount,edx
    .while @dwRemainingRecord != 0;//当剩余记录为零则结束循环
        .if @dwRemainingRecord >= BuffLimit
            sub @dwRemainingRecord,BuffLimit
            mov ecx, BuffLimit
        .else
            mov ecx, @dwRemainingRecord
            mov @dwRemainingRecord,0
        .endif
        push ecx
        invoke ReadFile, hFile, @lpFileBuf,sizeof STUDENT * BuffLimit, ADDR @dwNumberOfBytesRead,NULL
        .if eax == FALSE;//功能尚未写完，缺少回收内存机制
            call ErrorHandler
            mov eax, READ_FILE_FAIL
            ret
        .elseif @dwNumberOfBytesRead == 0;//文件没有更多数据，功能暂时不写。

        .endif
        mov edi,@lpFileBuf;//填入链表铰链指针
        pop ecx
        push ecx
        @@:;//有BUG,睡觉 明天记得修改 亲.
        mov edx,@dwLastNode
        mov (STUDENT ptr [edi]).LastPtr,edx;//向当前链表节存入上一节的地址
        mov edx,@dwNextNode
        mov (STUDENT ptr [edi]).NextPtr,edx;//向当前链表节存入下一节的地址
        mov @dwLastNode,edi
        add edi,sizeof STUDENT
        mov @dwNextNode,edi
        add @dwNextNode,sizeof STUDENT
        loop @B
        mov edi,@dwLastNode
        mov (STUDENT ptr[edi]).NextPtr,NULL
        mov esi,lpLinkedListInfo
        mov (LNF ptr [esi]).EndNodeAddress,edi;//将最后一节链表存入链表维护结构体 BUG BUG BUG F**K!
        pop eax
        mov ebx, sizeof STUDENT
        mul ebx
        invoke GlobalAlloc, GPTR, eax
        .if eax == FALSE
            call ErrorHandler
            xor eax,eax
            ret
        .else
            mov @lpFileBuf,eax
            add eax,sizeof STUDENT
            mov @dwNextNode,eax
        .endif
    .endw
    invoke GlobalFree,@lpFileBuf;//弃置最后一节未用的内存，将内存交还操作系统
    mov esi,lpLinkedListInfo
    mov eax, (LNF ptr [esi]).FirstNodeAddress;//返回调用者，给出返回值：链表首节
    ret
Read_SI_Records2LinkedList ENDP

OpenDataBaseFile PROC USES ebx ecx edx esi hWnd:DWORD,lpFileName:DWORD, lpFileSize:DWORD,lpLinkedListInfo:DWORD
    LOCAL @hFile:DWORD
    LOCAL @dwNumberOfBytesRead:DWORD
;//用于打开学生信息数据库文件并检查文件是否合法文件，如数据库不存在则新建数据库文件并初始化数据库文件头
;//如果文件安全打开，则读取文件内容至缓冲区并格式化学生信息条目并复制至调用程序指定的内存区域作成双向链表形式存放。
;//输入参数:例程句柄，数据库文件名，文件维护结构体，链表维护结构体.
;//返回值定义:详见头文件文件、内存、串/流错误码定义
    mov eax,hWnd;//引用hWnd防止警告，如果MessageBox使用该参数时删除这句。
    invoke CreateFile,\
        lpFileName, \
        GENERIC_READ or GENERIC_WRITE, \
        DO_NOT_SHARE, \
        NULL, \
        OPEN_ALWAYS, \
        FILE_ATTRIBUTE_NORMAL,\
         0;//打开数据库文件
    .if eax == INVALID_HANDLE_VALUE
        call ErrorHandler
        mov eax,OPEN_FILE_FAIL
        ret
    .endif
    mov @hFile,eax
    invoke GetFileSizeEx,@hFile,lpFileSize;//获取文件长度
    .if eax == FALSE
        call ErrorHandler
        mov eax,OPEN_FILE_ERROR_SIZE
        jmp CloseFile
    .endif
    mov esi,lpFileSize
    mov edx, (LARGE_INTEGER ptr[esi]).LowPart
    .if edx < 256;//文件长度小于文件头长度 准备重建数据库文件
        invoke MessageBox,NULL,ADDR szErrorHeaderFileSize,ADDR szErrorTitle,MB_YESNO or MB_ICONWARNING
        .if     eax == IDYES;//根据输入结果决定是否重建数据库 对话框选择“是”则初始化数据库文件。
            invoke InitializeFileHeader,@hFile
            invoke GetFileSizeEx, @hFile,lpFileSize
            .if eax == FALSE
                call ErrorHandler
                mov eax,WRITE_FILE_FAIL
                jmp CloseFile
            .endif
        .elseif eax == IDNO
            mov eax, OPEN_FILE_FAIL
            jmp CloseFile
        .else
            call ErrorHandler
            mov eax,UNKNOW_ERROR
            jmp CloseFile
        .endif
    .else;//长度大于文件头长度，检测文件长度是否合法
        push edx
        invoke SetFilePointer,@hFile, 0, 0, FILE_BEGIN;//将文件指针指向文件头并读取至内存
        invoke ReadFile,@hFile,ADDR szFileHeader,sizeof szFileHeader,ADDR @dwNumberOfBytesRead,NULL 
        mov eax, szFileHeader.Records
        mov ebx, szFileHeader.RecordSize
        mul ebx
        add eax, sizeof szFileHeader
        pop edx
        .if eax != edx
            mov eax,FILE_LENGTH_ILLEGAL
            jmp CloseFile
        .endif
    .endif
    invoke CRP, szFileHeader.FileHeaderSize, ADDR szFileHeader.DefineString
    ;//校验文件头，如通不过校验则关闭文件、给出错误码并返回调用程序
    .if eax != szFileHeader.FileHeaderCRC
        mov eax,THE_FILE_HEADER_CHECKSUM_DETECTED_A_PARITY_ERROR
        jmp CloseFile
    .endif
    .if szFileHeader.NeedPassword != FALSE;//判读数据库是否密码加密，功能暂未完成!!!
        mov eax,PASSWORD_NO_MATCH
    .endif
    ;//读取记录条目数，不为空记录则将记录读出并建立链表存储于内存并返回无错码(FALSE) 否则给出错误码并返回
    .if szFileHeader.Records != NULL
        invoke Read_SI_Records2LinkedList,@hFile,lpLinkedListInfo
    .else
        mov eax,NO_RECORD_BE_FIND
        mov edi,lpLinkedListInfo
        mov (LNF ptr [edi]).TotalNodeCount,NULL
        mov (LNF ptr [edi]).FirstNodeAddress,NULL
        mov (LNF ptr [edi]).EndNodeAddress,NULL
        jmp CloseFile
    .endif
    xor eax,eax;//函数执行成功 返回无错码(FALSE)
    CloseFile:
    push eax
    invoke CloseHandle,@hFile
    .if eax == FALSE
        call ErrorHandler
        pop eax
        mov eax,CLOSE_FILE_ERROR
        ret
    .endif
    pop eax
    ret
OpenDataBaseFile endp

SaveDataBaseFile proc USES ebx ecx edx esi edi hWnd : DWORD, lpFileName : DWORD, lpFileSize : DWORD, lpLinkedListInfo : DWORD
    LOCAL @hFile:DWORD
    LOCAL @dwNumberOfBytesRead:DWORD, @dwBytesWritten:DWORD
;//检查数据文件头是否合法文件，如数据库不存在则新建数据库文件并初始化数据库文件头
;//如果文件安全打开，则将链表数据写入文件。
;//输入参数:例程句柄，数据库文件名，文件维护结构体，链表维护结构体.
;//返回值定义:详见头文件文件、内存、串/流错误码定义
    mov eax,hWnd
    invoke CreateFile, \
            lpFileName, \
            GENERIC_READ or GENERIC_WRITE, \
            DO_NOT_SHARE, \
            NULL, \
            OPEN_ALWAYS, \
            FILE_ATTRIBUTE_NORMAL, 0;//打开数据库文件
    .if eax == INVALID_HANDLE_VALUE
        call ErrorHandler
        mov eax,OPEN_FILE_FAIL
        ret
    .endif
    mov @hFile,eax
    invoke GetFileSizeEx,@hFile,lpFileSize;//获取文件长度
    .if eax == FALSE
        call ErrorHandler
        mov eax,OPEN_FILE_ERROR_SIZE
        jmp CloseFile
    .endif
    mov esi,lpFileSize
    mov edx, (LARGE_INTEGER ptr[esi]).LowPart
    .if edx < 256;//文件长度小于文件头长度 准备重建数据库文件
        invoke MessageBox,NULL,ADDR szErrorHeaderFileSize,ADDR szErrorTitle,MB_YESNO or MB_ICONWARNING
        .if     eax == IDYES;//根据输入结果决定是否重建数据库 对话框选择“是”则初始化数据库文件。
            invoke InitializeFileHeader,@hFile
            invoke GetFileSizeEx, @hFile,lpFileSize
            .if eax == FALSE
                call ErrorHandler
                mov eax,WRITE_FILE_FAIL
                jmp CloseFile
            .endif
        .elseif eax == IDNO
            mov eax, OPEN_FILE_FAIL
            jmp CloseFile
        .else
            call ErrorHandler
            mov eax,UNKNOW_ERROR
            jmp CloseFile
        .endif
    .else;//长度大于文件头长度，检测文件长度是否合法
        push edx
        mov eax, szFileHeader.Records
        mov ebx, szFileHeader.RecordSize
        mul ebx
        add eax, sizeof szFileHeader
        pop edx
        .if eax != edx
            mov eax,FILE_LENGTH_ILLEGAL
            jmp CloseFile
        .endif
    .endif
    invoke SetFilePointer,@hFile, 0, 0, FILE_BEGIN;//将文件指针指向文件头并读取至内存
    invoke ReadFile,@hFile,ADDR szFileHeader,sizeof szFileHeader,ADDR @dwNumberOfBytesRead,NULL
    invoke CRP, szFileHeader.FileHeaderSize, ADDR szFileHeader.DefineString
    ;//校验文件头，如通不过校验则关闭文件、给出错误码并返回调用程序
    .if eax != szFileHeader.FileHeaderCRC
        mov eax,THE_FILE_HEADER_CHECKSUM_DETECTED_A_PARITY_ERROR
        jmp CloseFile
    .endif
    .if szFileHeader.NeedPassword != FALSE;//判读数据库是否密码加密，功能暂未完成!!!
        mov eax,PASSWORD_NO_MATCH
    .endif
;//将内存中的链表写入文件数据以及根据写入结果修改文件头并添加文件终结标志EOF
    mov esi,lpLinkedListInfo
    mov eax,(LNF ptr [esi]).TotalNodeCount
    .if (szFileHeader.AllowChange !=FALSE) && (eax != NULL);//如果允许修改文件标志为假则修改文件头
        mov esi, lpLinkedListInfo
        mov eax, (LNF ptr [esi]).TotalNodeCount
        mov szFileHeader.Records, eax
        mov szFileHeader.RecordSize, sizeof STUDENT
        inc szFileHeader.FileChangeCount
        invoke GetLocalTime,ADDR szFileHeader.DataBaseChangeTime
        invoke CRP, szFileHeader.FileHeaderSize,ADDR szFileHeader.DefineString
        mov szFileHeader.FileHeaderCRC,eax
        invoke SetFilePointer, @hFile,0,0,FILE_BEGIN
        invoke WriteFile, @hFile,ADDR szFileHeader,sizeof szFileHeader,ADDR @dwBytesWritten,NULL
        mov ebx, lpLinkedListInfo
        mov esi,(LNF ptr [ebx]).HeadNodeAddress
        .repeat
            invoke WriteFile, @hFile,esi, sizeof STUDENT, ADDR @dwBytesWritten,NULL
            mov ebx, (STUDENT ptr[esi]).NextPtr
            mov esi, ebx
        .until !esi
        invoke SetEndOfFile,@hFile
    .else
        mov eax,NOT_ALLOW_CHANGE_FILE
        jmp CloseFile
    .endif

    xor eax,eax;//函数执行成功 返回无错码(FALSE)
    CloseFile:
    push eax
    invoke CloseHandle,@hFile
    .if eax == FALSE
        call ErrorHandler
        pop eax
        mov eax,CLOSE_FILE_ERROR
        ret
    .endif
    pop eax
    ret
SaveDataBaseFile endp

AppendRecord PROC USES ebx ecx edx esi edi lpSIRecord:DWORD,lpLinkedListInfo:DWORD
    LOCAL @dwSerNum:DWORD
;//在内存中安全开辟空间并写入1条记录
;//
;//输入参数:
;//返回值定义:
    mov esi, lpLinkedListInfo
    mov eax, (LNF ptr [esi]).TotalNodeCount
    inc (LNF ptr [esi]).TotalNodeCount
    .if  eax != 0
        mov edx,0
        .repeat
            mov edi, (LNF ptr[esi]).FirstNodeAddress
            inc edx
            mov ecx, FALSE
            .repeat
                mov ebx, (STUDENT ptr [edi]).dwSerNum
                .if edx == ebx
                    mov ecx, TRUE
                .endif
                mov eax, (STUDENT ptr [edi]).NextPtr
                mov edi,eax 
            .until !eax
        .until !ecx
        mov @dwSerNum,edx
        invoke GlobalAlloc, GPTR, sizeof STUDENT
        push eax
        mov edi, (LNF ptr [esi]).FirstNodeAddress
        .repeat 
            mov esi,edi
            mov eax, (STUDENT ptr [edi]).NextPtr
            mov edi,eax
        .until !eax
        pop edi
        mov (STUDENT ptr [esi]).NextPtr,edi
        mov ebx, esi
        mov esi, lpSIRecord
        mov (STUDENT ptr [esi]).LastPtr,ebx
        mov (STUDENT ptr [esi]).NextPtr,NULL
        mov edx,@dwSerNum
        mov (STUDENT ptr [esi]).dwSerNum,edx;//还没写学号字串自动填入代码，但不影响运行
        push edi 
        mov ecx,sizeof STUDENT
        cld
        rep movsb
        mov esi, lpLinkedListInfo
        pop (LNF ptr [esi]).TailNodeAddress
    .else
        invoke GlobalAlloc, GPTR, sizeof STUDENT
        mov edi, lpLinkedListInfo
        mov (LNF ptr[edi]).HeadNodeAddress,eax
        mov esi, lpSIRecord
        mov (STUDENT ptr [esi]).LastPtr, NULL
        mov (STUDENT ptr [esi]).NextPtr, NULL
        mov (STUDENT ptr [esi]).dwSerNum, 1
        mov edi, eax
        mov ecx, sizeof STUDENT
        cld
        rep movsb
        mov (LNF ptr [esi]).TailNodeAddress, eax
    .endif
    xor eax,eax
    ret
AppendRecord ENDP

End LibMain