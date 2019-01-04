// SIMS_C.cpp : 定义应用程序的入口点。
//

#include "stdafx.h"
#include "SIMS_C.h"
#include "SIMSLib.h"

#define BuffLimit      20
#define TotalNodeCount 20
#define Counter        0
// 全局变量: 
HINSTANCE hInst;                                // 当前实例
char *szDataBaseFileName = ".\\sims.dat\0";      // 数据库文件
//char FileSize[sizeof kLARGE_INTEGER];
//unsigned int lpFileSize;
//kLARGE_INTEGER FileSize;
//PkLARGE_INTEGER *lpFileSize=(struct PkLARGE_INTEGER *)malloc(sizeof kLARGE_INTEGER);
LARGE_INTEGER large_integer;
struct STUDENT lpFileIOBuffer[BuffLimit];
DWORD dwErrorMsg;
DWORD hFile_SIMS_DATA;

// 此代码模块中包含的函数的前向声明: 


int APIENTRY wWinMain(_In_ HINSTANCE hInstance,
    _In_opt_ HINSTANCE hPrevInstance,
    _In_ LPWSTR    lpCmdLine,
    _In_ int       nCmdShow)
{
    UNREFERENCED_PARAMETER(hPrevInstance);
    UNREFERENCED_PARAMETER(lpCmdLine);

    // TODO: 在此放置代码。
    dwErrorMsg=OpenDataBaseFile(hInstance, szDataBaseFileName, &large_integer, &lpFileIOBuffer[0]);
   
    return 0;

}


