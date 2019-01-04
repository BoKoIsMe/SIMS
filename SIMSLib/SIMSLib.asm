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
Read_SI_Records2LinkedList PROTO hFile:HANDLE,lpLinkedListInfo:DWORD
RecyclePointAlloc          PROTO lpLinkedListInfo : DWORD
AppendRecord               PROTO lpSIRecord:DWORD,lpLinkedListInfo:DWORD
.data
	szFileHeader SIMSDataBaseFileHeader <>
.data?
	hInstance HANDLE ?

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

InitializeFileHeader PROC PRIVATE USES esi edi ecx,hFile:HANDLE
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

Read_SI_Records2LinkedList PROC PRIVATE USES edi esi ecx edx,hFile:HANDLE,lpLinkedListInfo:DWORD
    LOCAL @lpFileBuf:DWORD
    LOCAL @dwNumberOfBytesRead:DWORD
    LOCAL @dwRemainingRecord:DWORD,@dwLastNode:DWORD,@dwNextNode:DWORD
    LOCAL @dwFirstNodeFlag:BOOL,@dwLinkedNodeFlag:BOOL
;//读取学生信息记录并开辟内存用于存放记录链表
;//
;//输入参数:文件句柄 hFile ,链表信息结构指针 lpListNodeInfo
;//返回值定义:非零值为指向链表第一节的指针，为零则读取记录失败
    mov @dwFirstNodeFlag,TRUE;//初始化链表首节标志:布尔型变量
    mov @dwLinkedNodeFlag,TRUE;//初始化链表链接缓冲标志:布尔型变量
    mov @dwLastNode,NULL;//初始化上节链表地址，首节链表上节地址(LastNodeAddress)默认为NULL
    mov edx,szFileHeader.Records;//从文件头中读出记录总条目数并存入剩余记录变量中
    mov @dwRemainingRecord,edx;//存入剩余记录变量中-|
    mov edi, lpLinkedListInfo;//--------------------/
    mov(LNF ptr[edi]).TotalNodeCount, edx;//将链表维护结构体总计链表条目数初始化，填入读出条目数
        .repeat;//循环体
        .if @dwRemainingRecord >= BuffLimit;//当剩余记录条目大于缓冲读取限制则取最大缓冲数加载入读取计数器,并从剩余记录条目中扣除将要读出的条目数-
            sub @dwRemainingRecord,BuffLimit;//                                                                                                  |
            mov ecx, BuffLimit;//-----------------------------------------------------------------------------------------------------------------
        .else;//否则将剩余条目数加载入读取计数器并将剩余条目清零-
            mov ecx, @dwRemainingRecord;//                      |
            mov @dwRemainingRecord,0;//--------------------------
        .endif
        push ecx;//---------------------------------------------------------
        mov eax,sizeof STUDENT;//                                          |
        mul ecx;//                                                         |
        push eax;//根据剩余记录数计算内存申请大小和缓冲区大小数值并压栈保存-
        invoke GlobalAlloc, GPTR, eax;//向操作系统申请内存，并为内存链表建立循环做循环前数据准备
        .if eax == FALSE;//内存申请失败，做失败处理-
            call ErrorHandler;//                   |
            pop eax;//                             |
            xor eax, eax;//                        |
            ret;//----------------------------------
        .else
            mov @lpFileBuf,eax
            .if @dwFirstNodeFlag != FALSE ;//如果链表首节标记首节不为假则向链表维护结构体写入链表首地址信息
                mov edi, lpLinkedListInfo
                mov (LNF ptr[edi]).FirstNodeAddress, eax;//将链表首节地址装入链表维护结构体
                mov @dwFirstNodeFlag,FALSE
            .endif
            add eax,sizeof STUDENT
            mov @dwNextNode,eax
        .endif
        pop edx
        invoke ReadFile, hFile, @lpFileBuf,edx, ADDR @dwNumberOfBytesRead,NULL
        .if eax == FALSE;//功能尚未写完，缺少回收内存机制
            call ErrorHandler
            mov eax, READ_FILE_FAIL
            ret
        .elseif @dwNumberOfBytesRead == 0;//文件没有更多数据，功能暂时不写。
            nop;//空指令
        .endif
        mov edi,@lpFileBuf;//填入区块链表铰链指针
        .if !@dwLinkedNodeFlag
            mov esi,@dwLastNode
            mov (STUDENT ptr [esi]).NextPtr,edi
        .else
            mov @dwLinkedNodeFlag,FALSE
        .endif
        pop ecx;//从堆栈中取出记录数计数器数值
        @@:;//BUG已修正
        mov edx,@dwLastNode
        mov (STUDENT ptr [edi]).LastPtr,edx;//向当前链表节存入上一节的地址
        mov edx,@dwNextNode
        mov (STUDENT ptr [edi]).NextPtr,edx;//向当前链表节存入下一节的地址
        mov @dwLastNode,edi
        add edi,sizeof STUDENT;//将当前处理链表地址指向下一节可能存在的链表地址
        mov @dwNextNode,edi
        add @dwNextNode,sizeof STUDENT;//预计下节链表地址
        loop @B;//根据记录数计数器循环填写当前链表上/下节地址
        mov edi,@dwLastNode
        mov (STUDENT ptr[edi]).NextPtr,NULL;//?猜测?当前链表为最后一节链表填入NULL代表链表结束
    .until !@dwRemainingRecord;//当剩余记录为零则结束循环
    mov esi,lpLinkedListInfo
    mov (LNF ptr [esi]).TailNodeAddress,edi;//将最后一节链表存入链表维护结构体 BUG BUG BUG F**K!
    mov eax, (LNF ptr [esi]).FirstNodeAddress;//返回调用者，给出返回值：链表首节
    ret
Read_SI_Records2LinkedList ENDP

OpenDataBaseFile PROC USES ebx ecx edx esi hWnd:HANDLE,lpFileName:DWORD, lpFileSize:DWORD,lpLinkedListInfo:DWORD
    LOCAL @hFile:HANDLE
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

SaveDataBaseFile proc USES ebx ecx edx esi edi hWnd : HANDLE, lpFileName : DWORD, lpFileSize : DWORD, lpLinkedListInfo : DWORD
    LOCAL @hFile:HANDLE
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

RecyclePointAlloc proc PRIVATE USES esi edi ebx ecx edx lpLinkedListInfo:DWORD
;//尝试分配一个已回收的STUDENT结构体大小的内存指针给调用者，如回收栈内没有被回收的内存指针则返回NULL
;//
;//入口参数:链表维护结构体地址。
;//返回参数:如果函数执行成功则返回一个被回收的指针，否则返回NULL。
    mov esi,lpLinkedListInfo
    mov eax,(LNF ptr [esi]).GarbageRecycled.RecycleMemoryCount
    .if eax != NULL;//如栈内有被回收的指针，则执行以下指令；如栈内无被回收的指针，则返回NULL
        xor edx,edx
        dec eax;//自减1对齐0起始
        mov ebx,15
        div ebx;//余为堆栈数，模为栈内偏移
        mov edi,(LNF ptr[esi]).GarbageRecycled.EndRecycleStackAddress
        mov ebx,edx
        mov eax,(RPS ptr[edi+ebx*4]).RecyclePoint
        mov (RPS ptr[edi+ebx*4]).RecyclePoint,NULL
        dec (LNF ptr[esi]).GarbageRecycled.RecycleMemoryCount
        mov edx,(LNF ptr[esi]).GarbageRecycled.RecycleStackCount;//
        .if (ebx == NULL) && (edx != 1);//如果将要送出的指针是栈内仅有的一个且不为第一个栈则释放当前指针栈
            push eax
            mov ebx,(RPS ptr[edi]).LastRecycleStackAddress
            mov (LNF ptr[esi]).GarbageRecycled.EndRecycleStackAddress,ebx
            mov (RPS ptr[ebx]).NextRecycleStackAddress,NULL
            dec (LNF ptr[esi]).GarbageRecycled.RecycleStackCount
            invoke GlobalFree,edi
            pop eax
        .endif
    .else
        xor eax,eax;//return NULL;
    .endif
    ret
RecyclePointAlloc endp

AppendRecord PROC USES ebx ecx edx esi edi lpSIRecord:DWORD,lpLinkedListInfo:DWORD
    LOCAL @hSerNum:HANDLE
;//使用回收内存或在系统内存中安全开辟空间并写入1条记录
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
                mov ebx, (STUDENT ptr [edi]).hSerNum
                .if edx == ebx
                    mov ecx, TRUE
                .endif
                mov eax, (STUDENT ptr [edi]).NextPtr
                mov edi,eax 
            .until !eax
        .until !ecx
        mov @hSerNum,edx
        invoke RecyclePointAlloc,lpLinkedListInfo
        .if eax == NULL
            invoke GlobalAlloc, GPTR, sizeof STUDENT
        .endif
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
        mov edx,@hSerNum
        mov (STUDENT ptr [esi]).hSerNum,edx;//还没写学号字串自动填入代码，但不影响运行
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
        mov (STUDENT ptr [esi]).hSerNum, 1
        mov edi, eax
        mov ecx, sizeof STUDENT
        cld
        rep movsb
        mov (LNF ptr [esi]).TailNodeAddress, eax
    .endif
    xor eax,eax
    ret
AppendRecord ENDP

GetRecord proc USES ebx ecx edx esi edi hSerNum:HANDLE,lpStudentBuf:DWORD, lpstLinkedListInfo:DWORD
    ;//从内存记录链表中获取特定序号所代表的记录结构体并复制入缓冲区
    ;//
    ;//入口参数:序号 hSerNum:HANDLE , 链表抽取结构体缓存指针 lpStudentBuf:DWORD,链表维护结构体指针 lpstLinkedListInfo:DWORD
    ;//返回参数:Succeed:如果函数运行成功,则返回一个非零值。
    mov ebx,lpstLinkedListInfo
    mov esi,(LNF ptr [ebx]).HeadNodeAddress
    .repeat
        mov eax,(STUDENT ptr [esi]).hSerNum
        .if eax == hSerNum
            mov edi,lpStudentBuf
            mov ecx,sizeof STUDENT
            clc
            rep movsb
            .break
        .else
            mov ebx,(STUDENT ptr [esi]).NextPtr
            mov esi,ebx
            xor eax,eax
        .endif
    .until !esi
    ret
GetRecord endp

FindRecord proc USES ebx ecx edx esi edi
    ;//从内存记录链表中按条件查找符合条件的记录,并返回它们的序号
    ;//
    ;//入口参数:
    ;//返回参数:
    ret
FindRecord endp

DeleteRecord proc USES ebx ecx edx esi edi hSerNum:HANDLE,lpstLinkedListInfo:DWORD
    ;//从内存记录链表删除特定序号所代表的记录
    ;//
    ;//入口参数:序号 hSerNum:HANDLE (必须是非零值，否则会出现无法预知的错误) ,链表维护结构体指针 lpstLinkedListInfo:DWORD
    ;//返回参数:Succeed:如果函数运行成功,则返回一个非零值。
    mov ebx,lpstLinkedListInfo
    mov esi,(LNF ptr [ebx]).HeadNodeAddress;//取链表头指针装入esi
    .repeat;//遍历链表直至最后一节点，如未发现返回失败标志
        mov eax,(STUDENT ptr [esi]).hSerNum
        .if eax == hSerNum;//遍历链表搜索与指定句柄相符的链表节点
            mov edi,(STUDENT ptr[esi]).LastPtr;//找到相符节点，处理上节点指针指向铰链
            .if edi != NULL;//当前节点不为头节点则修改上一节点指针铰链
                mov ebx,(STUDENT ptr[esi]).NextPtr
                mov (STUDENT ptr [edi]).NextPtr,ebx
            .else;//当前节点是头节点，修改链表维护结构体中的头链地址指向
                mov ebx, lpstLinkedListInfo
                mov edx,(STUDENT ptr [esi]).NextPtr
                mov (LNF ptr [ebx]).HeadNodeAddress,edx
            .endif
            mov edi,(STUDENT ptr[esi]).NextPtr;//找到相符节点，处理下节点指针指向铰链
            .if edi != NULL;//当前节点不为头节点则修改下一节点指针铰链
                mov ebx,(STUDENT ptr[esi]).LastPtr
                mov (STUDENT ptr [edi]).LastPtr,ebx
            .else;//当前节点是尾节点，修改链表维护结构体中的尾链地址指向
                mov ebx, lpstLinkedListInfo
                mov edx,(STUDENT ptr [esi]).LastPtr
                mov (LNF ptr [ebx]).TailNodeAddress,edx
            .endif
            invoke RtlZeroMemory,esi,sizeof STUDENT;//当前节点已被注销，内存清零处置
            mov ebx, lpstLinkedListInfo
            mov edi,(LNF ptr [ebx]).GarbageRecycled.FirstRecycleStackAddress;//从链表维护结构体中取内存回收栈首地址
            mov ebx,(RPS ptr [edi]).NextRecycleStackAddress
            .while ebx != NULL;//遍历回收栈，寻找空余指针存放处
                mov edi,ebx
                mov ebx, (RPS ptr[edi]).NextRecycleStackAddress
            .endw
            mov ebx,-1
            .repeat
                .if ebx == 14;//当前回收栈满，新建下一栈用于存放被回收的指针
                    invoke GlobalAlloc,GPTR,sizeof RPS
                    mov ebx,eax
                    mov (RPS ptr[ebx]).LastRecycleStackAddress,edi
                    mov (RPS ptr[edi]).NextRecycleStackAddress,eax
                    mov edi,eax
                    mov ebx, lpstLinkedListInfo
                    inc (LNF ptr [ebx]).GarbageRecycled.RecycleStackCount;//被维护的栈计数自增1
                    mov (LNF ptr [ebx]).GarbageRecycled.EndRecycleStackAddress,eax
                    mov ebx,-1
                .endif
                inc ebx
                mov eax,(RPS ptr [edi+ebx*4]).RecyclePoint
            .until !eax;//栈内未使用的存放空间被找到则结束循环
            mov (RPS ptr [edi+ebx*4]).RecyclePoint,esi;//将被回收的指针放入栈中
            mov ebx, lpstLinkedListInfo
            inc (LNF ptr [ebx]).GarbageRecycled.RecycleMemoryCount;//被维护的回收指针计数自增1
            dec (LNF ptr [ebx]).TotalNodeCount;//总计链表节点计数自减1
            mov eax,esi
            .break
        .else
            mov ebx,(STUDENT ptr [esi]).NextPtr;//遍历链表下一节点
            mov esi,ebx
            xor eax,eax
            .break .if esi == NULL;//已至链表最后的节点 未发现与目标句柄匹配的节点 尝试删除失败返回
        .endif
    .until !esi
    ret
DeleteRecord endp

ChangeRecord proc USES ebx ecx edx esi edi hSerNum : HANDLE, lpStudentBuf : DWORD, lpstLinkedListInfo : DWORD
    ;//将缓冲中的记录写入特定序号所代表的记录链表项
    ;//
    ;//入口参数:
    ;//返回参数:
    ret
ChangeRecord endp

End LibMain