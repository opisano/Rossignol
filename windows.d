/*
This file is part of Rossignol.

Rossignol is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Rossignol is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Rossignol.  If not, see <http://www.gnu.org/licenses/>.

Copyright 2013 Olivier Pisano
*/

module windows;

version (Windows)
{

import std.conv;
import std.path;
import std.string;
import std.utf;
import core.sys.windows.windows;
import std.c.windows.windows;

import text;


// Missing Win32 declarations in std.c.windows.windows

enum PIPE_ACCESS_INBOUND  = 0x00000001;
enum PIPE_ACCESS_OUTBOUND = 0x00000002;
enum PIPE_ACCESS_DUPLEX   = 0x00000003;

enum PIPE_WAIT                  = 0x00000000;
enum PIPE_NOWAIT                = 0x00000001;
enum PIPE_READMODE_BYTE         = 0x00000000;
enum PIPE_READMODE_MESSAGE      = 0x00000002;
enum PIPE_TYPE_BYTE             = 0x00000000;
enum PIPE_TYPE_MESSAGE          = 0x00000004;
enum PIPE_ACCEPT_REMOTE_CLIENTS = 0x00000000;
enum PIPE_REJECT_REMOTE_CLIENTS = 0x00000008;

enum FILE_FLAG_FIRST_PIPE_INSTANCE = 0x00080000;

enum ERROR_ALREADY_EXISTS = 183;

enum
{
    CSIDL_DESKTOP                   = 0x0000,        
    CSIDL_INTERNET                  = 0x0001,        
    CSIDL_PROGRAMS                  = 0x0002,        
    CSIDL_CONTROLS                  = 0x0003,        
    CSIDL_PRINTERS                  = 0x0004,        
    CSIDL_PERSONAL                  = 0x0005,        
    CSIDL_FAVORITES                 = 0x0006,        
    CSIDL_STARTUP                   = 0x0007,        
    CSIDL_RECENT                    = 0x0008,        
    CSIDL_SENDTO                    = 0x0009,        
    CSIDL_BITBUCKET                 = 0x000a,        
    CSIDL_STARTMENU                 = 0x000b,        
    CSIDL_MYDOCUMENTS               = CSIDL_PERSONAL,
    CSIDL_MYMUSIC                   = 0x000d,        
    CSIDL_MYVIDEO                   = 0x000e,        
    CSIDL_DESKTOPDIRECTORY          = 0x0010,        
    CSIDL_DRIVES                    = 0x0011,        
    CSIDL_NETWORK                   = 0x0012,        
    CSIDL_NETHOOD                   = 0x0013,        
    CSIDL_FONTS                     = 0x0014,        
    CSIDL_TEMPLATES                 = 0x0015,        
    CSIDL_COMMON_STARTMENU          = 0x0016,        
    CSIDL_COMMON_PROGRAMS           = 0X0017,        
    CSIDL_COMMON_STARTUP            = 0x0018,        
    CSIDL_COMMON_DESKTOPDIRECTORY   = 0x0019,        
    CSIDL_APPDATA                   = 0x001a,        
    CSIDL_PRINTHOOD                 = 0x001b,

    CSIDL_FLAG_CREATE               = 0x8000
}


extern (Windows) 
{
	HANDLE CreateEventW(LPSECURITY_ATTRIBUTES lpEventAttributes,
						BOOL bManualReset,
						BOOL bInitialState, 
						LPCWSTR lpName);

	HANDLE CreateNamedPipeW(LPCWSTR lpName,
						   DWORD dwOpenMode,
						   DWORD dwPipeMode,
						   DWORD nMaxInstances,
						   DWORD nOutBufferSize,
						   DWORD nInBufferSize,
						   DWORD nDefaultTimeOut,
						   LPSECURITY_ATTRIBUTES lpSecurityAttributes);

    BOOL ConnectNamedPipe(HANDLE hNamedPipe,
                          OVERLAPPED* lpOverlapped);

    BOOL DisconnectNamedPipe(HANDLE hNamedPipe);

    HANDLE CreateMutexW(LPSECURITY_ATTRIBUTES lpSecurityAttributes,
                        BOOL bInitialOwner,
                        LPCWSTR lpName);
}



/**
 * Exception class for signaling Windows-API errors
 */
class WindowsException : Exception
{
	DWORD m_errorCode;

public:
	this(string message, DWORD errCode)
	{
		super(message);
		m_errorCode = errCode;
	}

	@property DWORD errorCode() const
	{
		return m_errorCode;
	}
}

private string getErrorMessage(DWORD errCode)
{
    // Get error message corresponding to error code 
	LPWSTR szErr;
	auto success = FormatMessageW(FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM,
								  null,
								  errCode,
								  0,
								  cast(LPWSTR)&szErr,
								  0,
								  null);
    // FormatMessageW failed
	if (success == 0)
	{
		throw new WindowsException("Unknow Windows error. Could not get error descrition.", 0);
	}
	else
	{
		// Convert to string
		auto msg = to!string(szErr);

		// Free memory allocated by FormatMessage
		LocalFree(szErr);

		return msg;
	}
}

/**
 * Creates and throws a WindowsException instance based on last Win32 error
 * code.
 */
void throwLastError()
{
	// Get Error code
	auto errCode = GetLastError();

	auto str = getErrorMessage(errCode);
    throw new WindowsException(str, errCode);
}

private enum IPCMode
{
    client,
    server
}

/**
 * A Windows named pipe
 */
struct IPC
{
private:
	HANDLE		m_handle;

    debug
    {
        IPCMode mode;
    }

public:

    /**
     * Create a server IPC for reading.
     *
     * params
     * - name the IPC name
     */
	static IPC createServer(string name)
	{
		IPC np;

        // Create named pipe
		np.m_handle = CreateNamedPipeW(toUTF16z(name),
										PIPE_ACCESS_INBOUND | FILE_FLAG_FIRST_PIPE_INSTANCE | FILE_FLAG_OVERLAPPED,
										PIPE_TYPE_BYTE | PIPE_WAIT,
										1,
										2048,
										2048,
										0,
										null);

		if (np.m_handle == INVALID_HANDLE_VALUE)
		{
			throwLastError();
		}

        debug
        {
            np.mode = IPCMode.server;
        }

		return np;
	}

    /**
     * Create a client IPC for writing.
     * 
     * params
     * - name the ipc name
     */
    static IPC createClient(string name)
    {
        IPC np;

        // Open named pipe
        np.m_handle = CreateFileW(toUTF16z(name),
                                  GENERIC_WRITE,
                                  0,
                                  null,
                                  OPEN_EXISTING,
                                  0,
                                  null);

        if (np.m_handle == INVALID_HANDLE_VALUE)
        {
            throwLastError();
        }

        debug
        {
            np.mode = IPCMode.client;
        }

        return np;
    }

	~this()
	{
		if (m_handle !is null)
		{
			CloseHandle(m_handle);
			m_handle = null;
		}
	}

    /**
     * Read data sent by the client
     */
	string read()
	{
        debug
        {
            assert (mode == IPCMode.server);
        }

		char[2048] buffer;
		DWORD bytesRead;

        // Wait for a client connection
        auto success = ConnectNamedPipe(m_handle, null);
        if (success == 0)
        {
            throwLastError();
        }

        // Read message from the client
        success = ReadFile(m_handle, buffer.ptr, buffer.length, &bytesRead, null);
        if (!success || bytesRead == 0)
        {
            throwLastError();
        }


        // disconnect immediately
        DisconnectNamedPipe(m_handle);


        return buffer[0..bytesRead].idup;
	}

    /**
     * Send data from client to server.
     */
    void write(string msg)
    {
        debug
        {
            assert (mode == IPCMode.client);
        }

        DWORD bytesWritten;
        auto success = WriteFile(m_handle,
                                 msg.ptr,
                                 msg.length,
                                 &bytesWritten,
                                 null);
        if (!success)
        {
            throwLastError();
        }
    }
}

/**
 * Modelizes a token, useful to detect 
 * if another instance of the application is running.
 */
struct Token
{
private:
    HANDLE m_handle;
    bool   m_owned;

public:
    static Token create(string name)
    {
        Token nm;
        // create a named mutex
        nm.m_handle = CreateMutexW(null, true, toUTF16z(name));

        // Check for errors
        if (nm.m_handle == null)
        {
            throwLastError();
        }

        // Check if we own the mutex
        nm.m_owned = !(GetLastError() == ERROR_ALREADY_EXISTS);
        return nm;
    }

    ~this()
    {
        if (m_handle)
        {
            CloseHandle(m_handle);
            m_handle = null;
        }
    }

    /**
     * Tells if we own the token (if it is the first instance of this 
     * application).
     */
    @property bool owned() const
    {
        return m_owned;
    }
}

string getUserSettingsDirectory()
{
    /* DMD 2.063 is lacking some function declaration in its shell32.lib, 
    so we must dynamically retrieve a pointer to the SHGetFolderPathW
    function.
    */
    alias extern(Windows) HRESULT function(HWND, int, HANDLE, DWORD, LPWSTR) func;

    // load shell32.dll
    func SHGetFolderPathW; 
    auto hModule = LoadLibraryW("Shell32.dll"w.ptr);

    if (hModule is null)
        throw new Exception("Cannot load shell32.dll");

    // don't forget to free hModule at scope exit
    scope (exit)
        FreeLibrary(hModule);

    // Get function address
    SHGetFolderPathW = cast(func) GetProcAddress(hModule, "SHGetFolderPathW");
    if (SHGetFolderPathW is null)
        throw new Exception("Cannot find SHGetFolderPathW address");

    // Retrieve application data folder
    wchar[MAX_PATH] szPath;
    SHGetFolderPathW(null, CSIDL_APPDATA|CSIDL_FLAG_CREATE, null, 0,
                     szPath.ptr);
    size_t len = slen(szPath.ptr);
    return to!string(szPath[0..len]);
}

string getApplicationPath()
{
    WCHAR[2048] szAppPath = void;
    DWORD nChars = GetModuleFileNameW(null, szAppPath.ptr, 2048);
    if (nChars == 0)
    {
        throwLastError();
    }
    
    auto s = to!string(szAppPath[0..nChars]);
    return dirName(s);
}

string getTokenName()
{
    return "Global\\RossignolMutex";
}

string getUserLanguage()
{
    alias extern(Windows) BOOL function(DWORD, PULONG, PWSTR, PULONG) func;

    // Load kernel32.dll
    func GetUserPreferredUILanguages;
    auto hModule = LoadLibraryW("Kernel32.dll"w.ptr);

    if (hModule is null)
        throw new Exception("Cannot load kernel32.dll");

    // don't forget to free hModule at scope exit
    scope (exit)
        FreeLibrary(hModule);

    GetUserPreferredUILanguages = cast(func) GetProcAddress(hModule, "GetUserPreferredUILanguages");

    ULONG ulLanguageCount;
    WCHAR[64] wszLangBuffer;
    ULONG ulBufferLength = wszLangBuffer.length;

    auto result = GetUserPreferredUILanguages(0,
                                              &ulLanguageCount,
                                              wszLangBuffer.ptr,
                                              &ulBufferLength);

    if (result == FALSE)
    {
        throwLastError();
    }

    if (ulLanguageCount == 0)
    {
        return null;
    }

    auto len = slen(wszLangBuffer.ptr);
    return to!string(wszLangBuffer[0..len]);
}

}

