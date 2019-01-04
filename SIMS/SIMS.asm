.686
.model flat, stdcall
option casemap : none

include    windows.inc
include    user32.inc
includelib user32.lib
include    kernel32.inc
includelib kernel32.lib
include    gdi32.inc
includelib gdi32.lib
include    SIMSLib.inc
includelib ..\DEBUG\SIMSLib.lib
include    Header.inc
include    Masm32.inc
includelib Masm32.lib
;//��������
BuffLimit EQU 20
TotalNodeCount = 20
Counter = 0
;//�ṹ����

;// LARGE_INTEGER UNION
;//    STRUCT
;//        LowPart  DWORD ?
;//        HighPart SWORD ?
;//    ENDS
;//    QuadPart QWORD ?
;// LARGE_INTEGER ENDS
;// windows.inc ������� LARGE_INTEGER

;//��������
        .data
StudentElsa     STUDENT       <<"Elsa",NULL,"FML ",NULL,"36060919841231999x",NULL>,"1",NULL,<100,100,100,100>,NULL,NULL,NULL>
StudentZhai      STUDENT       <<"�Ա�",NULL,"��",NULL,"36060419800831101X",NULL>,"1",NULL,<100,100,100,100>,NULL,NULL,NULL>
StudentLuo     STUDENT       <<"��ΰ��",NULL,"��",NULL,"360604198109211014",NULL>,"1",NULL,<100,100,100,100>,NULL,NULL,NULL>
StudentWang     STUDENT       <<"����",NULL,"��",NULL,"360604197909211088",NULL>,"1",NULL,<100,100,100,100>,NULL,NULL,NULL>
;//��̬�ڴ��������
        .const
szDataBaseFileName BYTE ".\sims.dat",0
lpDataBaseFileName EQU offset szDataBaseFileName
;//δ��ʼ����������
        .data?
stFileSize            LARGE_INTEGER <>
lpFileSize            EQU           offset stFileSize
stLinkedListInfo      LNF           <>
lpLinkedListInfo      EQU           offset stLinkedListInfo;//ѧ����Ϣ����ά���ṹ��
stRecyclePointStack   RPS           <>
lpstRecyclePointStack EQU           offset stRecyclePointStack
hInstance   	      HANDLE        ?
stStudentBuf          STUDENT       <>
lpstStudentBuf        EQU           offset stStudentBuf

;//�����
        .code
START:
main PROC
    invoke GetModuleHandle,NULL
    mov hInstance,eax
    mov stLinkedListInfo.GarbageRecycled.FirstRecycleStackAddress,lpstRecyclePointStack
    mov stLinkedListInfo.GarbageRecycled.EndRecycleStackAddress,lpstRecyclePointStack
    mov stLinkedListInfo.GarbageRecycled.RecycleStackCount,1
    invoke OpenDataBaseFile,hInstance,lpDataBaseFileName,lpFileSize,lpLinkedListInfo
    .if eax == NO_RECORD_BE_FIND
        mov ecx,6
        @@:
        invoke AppendRecord,offset StudentXiang,lpLinkedListInfo
        invoke AppendRecord,offset StudentZhai,lpLinkedListInfo
        invoke AppendRecord,offset StudentLuo,lpLinkedListInfo
        invoke AppendRecord,offset StudentWang,lpLinkedListInfo
        loop @B
        
    .endif
    invoke GetRecord,4,lpstStudentBuf,lpLinkedListInfo
    invoke DeleteRecord, 5,lpLinkedListInfo
    invoke AppendRecord, offset StudentWang, lpLinkedListInfo
    invoke DeleteRecord, 5, lpLinkedListInfo
    invoke DeleteRecord, 7,lpLinkedListInfo
    invoke DeleteRecord, 8, lpLinkedListInfo
    invoke DeleteRecord,10, lpLinkedListInfo
    invoke DeleteRecord,12, lpLinkedListInfo
    invoke DeleteRecord,15, lpLinkedListInfo
    invoke DeleteRecord,17, lpLinkedListInfo
    invoke DeleteRecord,16, lpLinkedListInfo
    invoke DeleteRecord,18, lpLinkedListInfo
    invoke DeleteRecord,14, lpLinkedListInfo
    invoke DeleteRecord,13, lpLinkedListInfo
    invoke DeleteRecord,11, lpLinkedListInfo
    invoke DeleteRecord, 9, lpLinkedListInfo
    invoke DeleteRecord, 6, lpLinkedListInfo
    invoke DeleteRecord,19, lpLinkedListInfo
    invoke DeleteRecord,20, lpLinkedListInfo
    invoke DeleteRecord, 5, lpLinkedListInfo
    invoke DeleteRecord,21, lpLinkedListInfo
    invoke DeleteRecord, 1, lpLinkedListInfo
    invoke DeleteRecord,28,lpLinkedListInfo
    invoke AppendRecord, offset StudentWang, lpLinkedListInfo
    invoke AppendRecord, offset StudentWang, lpLinkedListInfo
    invoke AppendRecord, offset StudentWang, lpLinkedListInfo
    invoke AppendRecord, offset StudentWang, lpLinkedListInfo
    mov ecx,0fh
    @@:
    invoke AppendRecord, offset StudentWang, lpLinkedListInfo
    loop @B
    mov esi, stLinkedListInfo.HeadNodeAddress
    .repeat
        mov ebx,(STUDENT ptr[esi]).NextPtr
        mov eax,(STUDENT ptr[esi]).hSerNum
        mov esi,ebx
    .until !ebx
    mov esi, stLinkedListInfo.TailNodeAddress
    .repeat
        mov ebx,(STUDENT ptr[esi]).LastPtr
        mov eax, (STUDENT ptr[esi]).hSerNum
        mov esi,ebx
    .until !ebx
    ;//invoke SaveDataBaseFile,hInstance,lpDataBaseFileName,lpFileSize,lpLinkedListInfo
    invoke ExitProcess, 0
main ENDP
        END START
