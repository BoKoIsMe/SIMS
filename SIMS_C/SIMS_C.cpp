// SIMS_C.cpp : ����Ӧ�ó������ڵ㡣
//

#include "stdafx.h"
#include "SIMS_C.h"
#include "SIMSLib.h"

#define BuffLimit      20
#define TotalNodeCount 20
#define Counter        0
// ȫ�ֱ���: 
HINSTANCE hInst;                                // ��ǰʵ��
char *szDataBaseFileName = ".\\sims.dat\0";      // ���ݿ��ļ�
//char FileSize[sizeof kLARGE_INTEGER];
//unsigned int lpFileSize;
//kLARGE_INTEGER FileSize;
//PkLARGE_INTEGER *lpFileSize=(struct PkLARGE_INTEGER *)malloc(sizeof kLARGE_INTEGER);
LARGE_INTEGER large_integer;
struct STUDENT lpFileIOBuffer[BuffLimit];
DWORD dwErrorMsg;
DWORD hFile_SIMS_DATA;

// �˴���ģ���а����ĺ�����ǰ������: 


int APIENTRY wWinMain(_In_ HINSTANCE hInstance,
    _In_opt_ HINSTANCE hPrevInstance,
    _In_ LPWSTR    lpCmdLine,
    _In_ int       nCmdShow)
{
    UNREFERENCED_PARAMETER(hPrevInstance);
    UNREFERENCED_PARAMETER(lpCmdLine);

    // TODO: �ڴ˷��ô��롣
    dwErrorMsg=OpenDataBaseFile(hInstance, szDataBaseFileName, &large_integer, &lpFileIOBuffer[0]);
   
    return 0;

}


