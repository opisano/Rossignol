/*
This file is part of Rossignol.

Foobar is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Foobar is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Foobar.  If not, see <http://www.gnu.org/licenses/>.

Copyright 2013 Olivier Pisano
*/

module windows;

version (Windows)
{

import std.conv;
import std.string;
import std.utf;
import core.sys.windows.windows;
import std.c.windows.windows;


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

    HANDLE CreateMutexW(
                        LPSECURITY_ATTRIBUTES lpSecurityAttributes,
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

string getErrorMessage(DWORD errCode)
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

enum PipeMode
{
    client,
    server
}

/**
 * A Windows named pipe
 */
struct NamedPipe
{
private:
	HANDLE		m_handle;

    debug
    {
        PipeMode mode;
    }

public:

    /**
     * Create a server named pipe for reading.
     *
     * params
     * - name the pipe name
     */
	static NamedPipe createServerPipe(string name)
	{
		NamedPipe np;

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
            np.mode = PipeMode.server;
        }

		return np;
	}

    /**
     * Create a client pipe for writing.
     * 
     * params
     * - name the pipe name
     */
    static NamedPipe createClientPipe(string name)
    {
        NamedPipe np;

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
            np.mode = PipeMode.client;
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
            assert (mode == PipeMode.server);
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
            assert (mode == PipeMode.client);
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
 * Modelizes a named mutex, useful to detect 
 * if another instance of the application is running.
 */
struct NamedMutex
{
private:
    HANDLE m_handle;
    bool   m_owned;

public:
    static NamedMutex create(string name)
    {
        NamedMutex nm;
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
     * Tells if we own the mutex (if it is the first instance of this 
     * application).
     */
    @property bool owned() const pure
    {
        return m_owned;
    }
}

}

