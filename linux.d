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

module linux;

version (linux)
{
    
import core.stdc.errno;
import core.stdc.string;
import core.sys.posix.fcntl;
import core.sys.posix.pwd;
import core.sys.posix.unistd;
import core.sys.posix.sys.socket;
import core.sys.posix.sys.types;
import core.sys.posix.sys.un;

import std.conv;
import std.path;
import std.string;

/**
 * Exception class for signaling linux API errors.
 */
class LinuxException : Exception
{
    int m_errorCode;
    
public:
    this(string message, int errCode)
    {
        super(message);
        m_errorCode = errCode;
    }
    
    @property int errorCode() const
    {
        return m_errorCode;
    }
}

private string getErrorMessage(int errCode)
{
    auto msg = strerror(errCode);
    return to!string(msg);
}

private void throwLastError()
{
    auto errCode = errno;
    auto str = getErrorMessage(errCode);
    throw new LinuxException(str, errCode);
}

private enum IPCMode
{
    client,
    server
}

/**
 * An IPC communication mecanism. 
 * On Linux, uses UNIX domain sockets to communicate.
 */
struct IPC
{
private:
    // socket handle
    int m_handle = -1;
    
    debug
    {
        IPCMode mode;
    }

public:
    /**
     * Create a server IPC for reading.
     *
     * params
     * - name the IPC name.
     */
    static IPC createServer(string name)
    {
        IPC ipc;
        
        // create server unix socket
        ipc.m_handle = socket(AF_UNIX, SOCK_STREAM, 0);
        
        if (ipc.m_handle < 0)
        {
            throwLastError();
        }
        
        // in case of future error during this init
        scope (failure)
        {
            close(ipc.m_handle); // close the server socket
        }
        
        // bind socket to IPC name
        auto szName = toStringz(name);
        sockaddr_un local;
        local.sun_family = AF_UNIX;
        strcpy(cast(char*)local.sun_path.ptr, szName);
        unlink(szName); // to prevent EINVAL
        uint len = cast(uint)(strlen(szName) + local.sun_family.sizeof);
        auto success = bind(ipc.m_handle, cast(const sockaddr*)&local, len);
        
        if (success == -1)
        {
            throwLastError();
        }
        
        success = listen(ipc.m_handle, 1);
        if (success == -1)
        {
            throwLastError();
        }
        
        debug
        {
            ipc.mode = IPCMode.server;
        }
        
        return ipc;
    }
    
    /**
     * Create a client IPC for writing.
     */
    static IPC createClient(string name)
    {
        IPC ipc;
        
        // Create unix client socket
        ipc.m_handle = socket(AF_UNIX, SOCK_STREAM, 0);
        if (ipc.m_handle < 0)
        {
            throwLastError();
        }
        
        // in case of future error during this init
        scope (failure)
        {
            // close client socket
            close(ipc.m_handle);
        }
        
        // connect
        auto szName = toStringz(name);
        sockaddr_un remote;
        remote.sun_family = AF_UNIX;
        strcpy(cast(char*)remote.sun_path, szName);
        uint len = cast(uint)(strlen(szName) + remote.sun_family.sizeof);
        auto success = connect(ipc.m_handle, cast(const sockaddr*)&remote, len);
        
        if (success < 0)
        {
            throwLastError();
        }
        
        debug
        {
            ipc.mode = IPCMode.client;
        }
        
        return ipc;
    }
    
    ~this()
    {
        if (m_handle != -1)
        {
            close(m_handle);
            m_handle = -1;
        }
    }
    
    /**
     * Read data sent by the client.
     */
    string read()
    {
        debug
        {
            assert (mode == IPCMode.server);
        }
        
        // wait for client connection
        sockaddr_un remote;
        uint t = cast(uint)remote.sizeof;
        auto client_handle = accept(m_handle, cast(sockaddr*)&remote, &t); 
        if (client_handle < 0)
        {
            throwLastError();
        }
        
        // Read message from the client
        char[2048] buffer;
        auto bytesRead = recv(client_handle, buffer.ptr, buffer.length, 0);
        if (bytesRead < 0)
        {
            throwLastError();
        }
        
        // disconnect immediately
        close(client_handle);
        
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
        
        auto bytesWritten = send(m_handle, msg.ptr, msg.length, 0);
        if (bytesWritten < 0)
        {
            throwLastError();
        }
    }
}


/**
 * Modelizes a token used for detecting if another instance of the 
 * application is running.
 */
struct Token
{
private:
    int m_handle;
    bool m_owned;
    string m_name;
    
public:
    static Token create(string name)
    {
        Token tok;
        // try to open a non-existent file. 
        tok.m_handle = open(toStringz(name), O_WRONLY | O_CREAT | O_EXCL);
        
        // check for errors
        if (tok.m_handle < 0)
        {
            // if an error other than "file already exist" occured
            if (errno != EEXIST)
            {
                throwLastError();
            }
        }
        else // if no error occured and file didn't exist
        {
            tok.m_owned = true;
            tok.m_name = name;
        }
        return tok;
    }
    
    ~this()
    {
        if (m_handle >= 0) // if we own the token
        {
            close(m_handle);
            unlink(toStringz(m_name)); // delete owned file
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

string getTokenName()
{
    auto pw = getpwuid(getuid());
    if (pw is null)
    {
        throwLastError();
    }
    
    return buildPath(to!string((*pw).pw_dir), ".RossignolMutex");
}

/**
 * Returns a string identifying where user settings should be put.
 */
string getUserSettingsDirectory()
{
    // According to freedesktop.org, user settings should be put in ~/.config
    
    auto pw = getpwuid(getuid());
    if (pw is null)
    {
        throwLastError();
    }
    
    string userdir = to!string((*pw).pw_dir);
    return buildPath(userdir, ".config");
}

/**
 * Return the absolute path to this process executable.
 */
string getApplicationPath()
{
    char[2048] buffer = void;
    auto count = readlink(toStringz("/proc/self/exe"), buffer.ptr, 
        buffer.length);
    
    if (count < 0)
    {
        throwLastError();
    }
    
    auto s = buffer[0..count].idup;
    return dirName(s);
}
    
}
