#pragma once
#include "stdafx.h"
#define MAX       20
#define IDLEN     18

typedef union _kLARGE_INTEGER {
    struct {
        DWORD LowPart;
        LONG  HighPart;
    };
    LONGLONG QuadPart;
} kLARGE_INTEGER, *PkLARGE_INTEGER;

typedef struct iSYSTEMTIME
{
    WORD wYear;
    WORD wMonth;
    WORD wDayOfWeek;
    WORD wDay;
    WORD wHour;
    WORD wMinute;
    WORD wSecond;
    WORD wMilliseconds;
} *PiSYSTEMTIME, *LPiSYSTEMTIME;

typedef struct PINF
{
    char szName[MAX];
    char szSex[MAX];
    char szID[IDLEN];
}*PPINF, *LPPINF;

typedef struct THEMARK
{
    DWORD chinese;
    DWORD mathematic;
    DWORD english;
    DWORD computer;
}*PTHEMARK, *LPTHEMARK;

typedef struct STUDENT
{
    PINF PersonalInformation;
    DWORD dwNum[MAX];
    THEMARK mark;
    DWORD dwSerNum;
    DWORD LastPtr;
    DWORD NextPtr;
}*PSTUDENT, *LPSTUDENT;

//学生信息系统数据库文件头结构定义
typedef struct SIMSDefine
{
    char *DataBaseName = "SIMSDATABASE\0";
    char *DataBaseVersion = "V1.0\0";
}*PSIMSDefine, *LPSIMSDefine;

typedef struct SIMSDataBaseFileHeader
{
    DWORD FileHeaderSize = sizeof SIMSDataBaseFileHeader - (sizeof DWORD * 2);
    SIMSDefine DefineString;
    DWORD Records;
    DWORD RecordSize = sizeof STUDENT;
    iSYSTEMTIME DataBaseCreateTime;
    iSYSTEMTIME DataBaseChangeTime;
    DWORD FileChangeCount;
    DWORD NeedPassword = FALSE;
    char DataBasePassword[20];
    char XORword = 'X';
    DWORD AllowChange = TRUE;
    char Nouses[(256 - sizeof SIMSDefine - (sizeof iSYSTEMTIME * 2) - (sizeof DWORD * 7) - 21)];
    DWORD FileHeaderCRC;
}*PSIMSDataBaseFileHeader, *LPSIMSDataBaseFileHeader;

#pragma comment(lib,"..\\Debug\\SIMSLib.lib")
extern "C" int __stdcall OpenDataBaseFile(HANDLE hWnd, char *lpFileName, PLARGE_INTEGER large_integer, STUDENT *lpFileIOBuffer);
