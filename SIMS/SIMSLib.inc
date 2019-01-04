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
OpenDataBaseFile	PROTO hWnd :HANDLE,lpFileName:DWORD,lpFileSize:DWORD,lpLinkedListInfo:DWORD
LoadDataBaseFile    EQU OpenDataBaseFile
SaveDataBaseFile    PROTO hWnd : HANDLE, lpFileName : DWORD, lpFileSize : DWORD, lpLinkedListInfo : DWORD
CRP                 PROTO len : DWORD, lpCRCSTRING : DWORD
GetRecord           PROTO hSerNum:HANDLE,lpStudentBuf:DWORD,lpstLinkedListInfo:DWORD
AppendRecord        PROTO lpSIRecord:DWORD,lpLinkedListInfo:DWORD
DeleteRecord        PROTO hSerNum:HANDLE,lpstLinkedListInfo:DWORD
