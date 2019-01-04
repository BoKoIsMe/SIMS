;//学生信息记录结构定义
MAX       EQU 20
IDLEN     EQU 18

PINF STRUCT
szName              BYTE MAX    dup(? )
                    BYTE ?
szSex               BYTE MAX    dup(? )
                    BYTE ?
szID                BYTE IDLEN  dup(? )
                    BYTE ?
PINF ENDS

THEMARK STRUCT
chinese             DWORD ?
mathematic          DWORD ?
english             DWORD ?
computer            DWORD ?
THEMARK ENDS

STUDENT STRUCT
PersonalInformation PINF    <>
dwNum               BYTE    MAX dup(? )
                    BYTE    ?
mark                THEMARK <>
hSerNum             HANDLE  ?
LastPtr             DWORD   ?
NextPtr             DWORD   ?
STUDENT ENDS



;//学生信息系统数据库文件头结构定义
SIMSDefine STRUCT
DataBaseName       BYTE       "SIMSDATABASE", 0
DataBaseVersion    BYTE       "V1.0", 0
SIMSDefine ENDS

;//TheClock STRUCT
;//    Hour               BYTE       "00"
;//    Minute             BYTE       "00"
;//    Second             BYTE       "00"
;//TheClock ENDS

;//TheDate STRUCT
;//    Year               BYTE       "2000"
;//    Month              BYTE       "01"
;//    Day                BYTE       "01"
;//    Clock              TheClock   <>
;//    EndOfString        BYTE       NULL
;//TheDate ENDS

SIMSDataBaseFileHeader STRUCT
FileHeaderSize     DWORD      sizeof SIMSDataBaseFileHeader - (sizeof DWORD * 2)
DefineString       SIMSDefine <>
Records            DWORD      ?
RecordSize         DWORD      sizeof STUDENT
DataBaseCreateTime SYSTEMTIME <>
DataBaseChangeTime SYSTEMTIME <>
FileChangeCount    DWORD      ?
NeedPassword       DWORD      FALSE
DataBasePassword   BYTE       20 dup(? )
XORword            BYTE       'X'
AllowChange        DWORD      TRUE
Nouses             BYTE       (256 - sizeof SIMSDefine - (sizeof SYSTEMTIME * 2) - (sizeof DWORD * 7) - 21) dup (?)
FileHeaderCRC      DWORD      ?
SIMSDataBaseFileHeader ENDS

MRS STRUCT
    FirstRecycleStackAddress DWORD ?
    EndRecycleStackAddress   DWORD ?
    RecycleMemoryCount       DWORD ?
    RecycleStackCount        DWORD ?
MRS ENDS

LNF STRUCT
    TotalNodeCount   DWORD ?
    FirstNodeAddress DWORD ?
    HeadNodeAddress  EQU   FirstNodeAddress
    EndNodeAddress   DWORD ?
    TailNodeAddress  EQU   EndNodeAddress
    GarbageRecycled  MRS   <>
LNF ENDS

RPS STRUCT
    RecyclePoint            EQU   RMP_01
    RMP_01                  DWORD ?
    RMP_02                  DWORD ?
    RMP_03                  DWORD ?
    RMP_04                  DWORD ?
    RMP_05                  DWORD ?
    RMP_06                  DWORD ?
    RMP_07                  DWORD ?
    RMP_08                  DWORD ?
    RMP_09                  DWORD ?
    RMP_0A                  DWORD ?
    RMP_0B                  DWORD ?
    RMP_0C                  DWORD ?
    RMP_0D                  DWORD ?
    RMP_0E                  DWORD ?
    RMP_0F                  DWORD ?
    LastRecycleStackAddress DWORD ?
    NextRecycleStackAddress DWORD ?
RPS ENDS
