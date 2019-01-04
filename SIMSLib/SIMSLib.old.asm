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
    szErrorTitle          BYTE "����", 0
    szErrorHeaderFileSize BYTE "�ļ�ͷ���������ȷǷ����Ƿ����³�ʼ�����ݿ��ļ�",0
    szErrorHeaderFileCRC  BYTE "�ļ�ͷ�������޷�ͨ��ѭ��У�飬���ݿ����ƻ��޷��޸���ѡ���ǡ����ݽ���ʧ����ʼ����ѡ�񡰷񡱷��������ļ���",0
	
.CODE

;//���.���DLL��Ҫ������Դ,��Ҫ����hIinstDLL��������ȫ�ֱ���.������ģ����
;//ʹ��GetModuleHandle��õ���Զ��������ľ��
LibMain proc hInstDLL:DWORD, reason:DWORD, unused:DWORD
	.if reason == DLL_PROCESS_ATTACH					;//��̬�ⱻ����ʱ����,����0����ʧ��!
		mov eax,hInstDLL
		mov hInstance,eax
		
		mov eax,TRUE
		ret
	.elseif reason == DLL_PROCESS_DETACH
		
	.elseif reason == DLL_THREAD_ATTACH
		
	.elseif reason == DLL_THREAD_DETACH
		mov eax,hInstDLL
		mov hInstance,eax
            		;//��Ӵ������
        mov eax,unused
		mov eax,TRUE
		ret
	.endif
ret
LibMain Endp

;//����������õĶ�̬���Ӻ�������
;//MsgBox proc hWnd,lpszText,fStyle
;//	invoke MessageBox, hWnd, lpszText, offset lpszByDll, fStyle
;// ret
;// MsgBox endp

ErrorHandler PROC PRIVATE
;// ��ʾ���ʵ�ϵͳ������Ϣ
        .data
pErrorMsg DWORD ? ;// ָ�������Ϣ��ָ��
messageID DWORD ?
        .code
    INVOKE GetLastError;// ��EAX�з�����ϢID
    mov messageID, eax

;// ��ȡ��Ӧ����Ϣ�ַ���
    INVOKE FormatMessage, FORMAT_MESSAGE_ALLOCATE_BUFFER + FORMAT_MESSAGE_FROM_SYSTEM, NULL, messageID, NULL, ADDR pErrorMsg, NULL, NULL

;// ��ʾ������Ϣ
    INVOKE MessageBox, NULL, pErrorMsg, ADDR szErrorTitle, MB_ICONERROR + MB_OK

;// �ͷ���Ϣ�ַ���
    INVOKE LocalFree, pErrorMsg
    ret
ErrorHandler ENDP

CRP proc USES esi len:DWORD,lpCRCString:DWORD
;//���������ĳ��� �Ա�Ĵ���CRCУ���Ⲣ����У����
;//
;//�������:������ len:DWORD Nλ��������ָ�� lpCRCString:DWORD Kλ
;//����ֵ����:CRC������ Rλ
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
;//���ڳ�ʼ�����ݿ��ļ�ͷ����д���ļ���
;//
;//
;//�������:�ļ���� hFile
;//����ֵ����:����ֵΪ�� void return
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
;//��ȡѧ����Ϣ��¼�������ڴ����ڴ�ż�¼����
;//
;//�������:�ļ���� hFile ,������Ϣ�ṹָ�� lpListNodeInfo
;//����ֵ����:����ֵΪָ�������һ�ڵ�ָ�룬Ϊ�����ȡ��¼ʧ��
    mov @dwLastNode,NULL
    invoke GlobalAlloc, GPTR, sizeof STUDENT * BuffLimit;//�����ϵͳ�����ڴ棬��Ϊ�ڴ�������ѭ����ѭ��ǰ����׼��
    .if eax == FALSE
        call ErrorHandler
        xor eax,eax
        ret
    .else
        mov @lpFileBuf,eax
        mov edi, lpLinkedListInfo
        mov (LNF ptr[edi]).FirstNodeAddress, eax;//�������׽ڵ�ַװ������ά���ṹ��
        add eax,sizeof STUDENT
        mov @dwNextNode,eax
    .endif
    mov edx,szFileHeader.Records
    mov @dwRemainingRecord,edx
    mov edi,lpLinkedListInfo
    mov (LNF ptr [edi]).TotalNodeCount,edx
    .while @dwRemainingRecord != 0;//��ʣ���¼Ϊ�������ѭ��
        .if @dwRemainingRecord >= BuffLimit
            sub @dwRemainingRecord,BuffLimit
            mov ecx, BuffLimit
        .else
            mov ecx, @dwRemainingRecord
            mov @dwRemainingRecord,0
        .endif
        push ecx
        invoke ReadFile, hFile, @lpFileBuf,sizeof STUDENT * BuffLimit, ADDR @dwNumberOfBytesRead,NULL
        .if eax == FALSE;//������δд�꣬ȱ�ٻ����ڴ����
            call ErrorHandler
            mov eax, READ_FILE_FAIL
            ret
        .elseif @dwNumberOfBytesRead == 0;//�ļ�û�и������ݣ�������ʱ��д��

        .endif
        mov edi,@lpFileBuf;//�����������ָ��
        pop ecx
        push ecx
        @@:;//��BUG,˯�� ����ǵ��޸� ��.
        mov edx,@dwLastNode
        mov (STUDENT ptr [edi]).LastPtr,edx;//��ǰ����ڴ�����һ�ڵĵ�ַ
        mov edx,@dwNextNode
        mov (STUDENT ptr [edi]).NextPtr,edx;//��ǰ����ڴ�����һ�ڵĵ�ַ
        mov @dwLastNode,edi
        add edi,sizeof STUDENT
        mov @dwNextNode,edi
        add @dwNextNode,sizeof STUDENT
        loop @B
        mov edi,@dwLastNode
        mov (STUDENT ptr[edi]).NextPtr,NULL
        mov esi,lpLinkedListInfo
        mov (LNF ptr [esi]).EndNodeAddress,edi;//�����һ�������������ά���ṹ�� BUG BUG BUG F**K!
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
    invoke GlobalFree,@lpFileBuf;//�������һ��δ�õ��ڴ棬���ڴ潻������ϵͳ
    mov esi,lpLinkedListInfo
    mov eax, (LNF ptr [esi]).FirstNodeAddress;//���ص����ߣ���������ֵ�������׽�
    ret
Read_SI_Records2LinkedList ENDP

OpenDataBaseFile PROC USES ebx ecx edx esi hWnd:DWORD,lpFileName:DWORD, lpFileSize:DWORD,lpLinkedListInfo:DWORD
    LOCAL @hFile:DWORD
    LOCAL @dwNumberOfBytesRead:DWORD
;//���ڴ�ѧ����Ϣ���ݿ��ļ�������ļ��Ƿ�Ϸ��ļ��������ݿⲻ�������½����ݿ��ļ�����ʼ�����ݿ��ļ�ͷ
;//����ļ���ȫ�򿪣����ȡ�ļ�����������������ʽ��ѧ����Ϣ��Ŀ�����������ó���ָ�����ڴ���������˫��������ʽ��š�
;//�������:���̾�������ݿ��ļ������ļ�ά���ṹ�壬����ά���ṹ��.
;//����ֵ����:���ͷ�ļ��ļ����ڴ桢��/�������붨��
    mov eax,hWnd;//����hWnd��ֹ���棬���MessageBoxʹ�øò���ʱɾ����䡣
    invoke CreateFile,\
        lpFileName, \
        GENERIC_READ or GENERIC_WRITE, \
        DO_NOT_SHARE, \
        NULL, \
        OPEN_ALWAYS, \
        FILE_ATTRIBUTE_NORMAL,\
         0;//�����ݿ��ļ�
    .if eax == INVALID_HANDLE_VALUE
        call ErrorHandler
        mov eax,OPEN_FILE_FAIL
        ret
    .endif
    mov @hFile,eax
    invoke GetFileSizeEx,@hFile,lpFileSize;//��ȡ�ļ�����
    .if eax == FALSE
        call ErrorHandler
        mov eax,OPEN_FILE_ERROR_SIZE
        jmp CloseFile
    .endif
    mov esi,lpFileSize
    mov edx, (LARGE_INTEGER ptr[esi]).LowPart
    .if edx < 256;//�ļ�����С���ļ�ͷ���� ׼���ؽ����ݿ��ļ�
        invoke MessageBox,NULL,ADDR szErrorHeaderFileSize,ADDR szErrorTitle,MB_YESNO or MB_ICONWARNING
        .if     eax == IDYES;//���������������Ƿ��ؽ����ݿ� �Ի���ѡ���ǡ����ʼ�����ݿ��ļ���
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
    .else;//���ȴ����ļ�ͷ���ȣ�����ļ������Ƿ�Ϸ�
        push edx
        invoke SetFilePointer,@hFile, 0, 0, FILE_BEGIN;//���ļ�ָ��ָ���ļ�ͷ����ȡ���ڴ�
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
    ;//У���ļ�ͷ����ͨ����У����ر��ļ������������벢���ص��ó���
    .if eax != szFileHeader.FileHeaderCRC
        mov eax,THE_FILE_HEADER_CHECKSUM_DETECTED_A_PARITY_ERROR
        jmp CloseFile
    .endif
    .if szFileHeader.NeedPassword != FALSE;//�ж����ݿ��Ƿ�������ܣ�������δ���!!!
        mov eax,PASSWORD_NO_MATCH
    .endif
    ;//��ȡ��¼��Ŀ������Ϊ�ռ�¼�򽫼�¼��������������洢���ڴ沢�����޴���(FALSE) ������������벢����
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
    xor eax,eax;//����ִ�гɹ� �����޴���(FALSE)
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
;//��������ļ�ͷ�Ƿ�Ϸ��ļ��������ݿⲻ�������½����ݿ��ļ�����ʼ�����ݿ��ļ�ͷ
;//����ļ���ȫ�򿪣�����������д���ļ���
;//�������:���̾�������ݿ��ļ������ļ�ά���ṹ�壬����ά���ṹ��.
;//����ֵ����:���ͷ�ļ��ļ����ڴ桢��/�������붨��
    mov eax,hWnd
    invoke CreateFile, \
            lpFileName, \
            GENERIC_READ or GENERIC_WRITE, \
            DO_NOT_SHARE, \
            NULL, \
            OPEN_ALWAYS, \
            FILE_ATTRIBUTE_NORMAL, 0;//�����ݿ��ļ�
    .if eax == INVALID_HANDLE_VALUE
        call ErrorHandler
        mov eax,OPEN_FILE_FAIL
        ret
    .endif
    mov @hFile,eax
    invoke GetFileSizeEx,@hFile,lpFileSize;//��ȡ�ļ�����
    .if eax == FALSE
        call ErrorHandler
        mov eax,OPEN_FILE_ERROR_SIZE
        jmp CloseFile
    .endif
    mov esi,lpFileSize
    mov edx, (LARGE_INTEGER ptr[esi]).LowPart
    .if edx < 256;//�ļ�����С���ļ�ͷ���� ׼���ؽ����ݿ��ļ�
        invoke MessageBox,NULL,ADDR szErrorHeaderFileSize,ADDR szErrorTitle,MB_YESNO or MB_ICONWARNING
        .if     eax == IDYES;//���������������Ƿ��ؽ����ݿ� �Ի���ѡ���ǡ����ʼ�����ݿ��ļ���
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
    .else;//���ȴ����ļ�ͷ���ȣ�����ļ������Ƿ�Ϸ�
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
    invoke SetFilePointer,@hFile, 0, 0, FILE_BEGIN;//���ļ�ָ��ָ���ļ�ͷ����ȡ���ڴ�
    invoke ReadFile,@hFile,ADDR szFileHeader,sizeof szFileHeader,ADDR @dwNumberOfBytesRead,NULL
    invoke CRP, szFileHeader.FileHeaderSize, ADDR szFileHeader.DefineString
    ;//У���ļ�ͷ����ͨ����У����ر��ļ������������벢���ص��ó���
    .if eax != szFileHeader.FileHeaderCRC
        mov eax,THE_FILE_HEADER_CHECKSUM_DETECTED_A_PARITY_ERROR
        jmp CloseFile
    .endif
    .if szFileHeader.NeedPassword != FALSE;//�ж����ݿ��Ƿ�������ܣ�������δ���!!!
        mov eax,PASSWORD_NO_MATCH
    .endif
;//���ڴ��е�����д���ļ������Լ�����д�����޸��ļ�ͷ������ļ��ս��־EOF
    mov esi,lpLinkedListInfo
    mov eax,(LNF ptr [esi]).TotalNodeCount
    .if (szFileHeader.AllowChange !=FALSE) && (eax != NULL);//��������޸��ļ���־Ϊ�����޸��ļ�ͷ
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

    xor eax,eax;//����ִ�гɹ� �����޴���(FALSE)
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
;//���ڴ��а�ȫ���ٿռ䲢д��1����¼
;//
;//�������:
;//����ֵ����:
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
        mov (STUDENT ptr [esi]).dwSerNum,edx;//��ûдѧ���ִ��Զ�������룬����Ӱ������
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