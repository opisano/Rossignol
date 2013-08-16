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

module system;

import std.array;
import std.conv;
import std.path;
import std.range;
import std.traits;

import std.c.locale;

// used for interacting with C code...
size_t slen(T)(const(T)* str) pure nothrow
		if (isSomeChar!T)
{
	size_t count;
	while (*str++)
		count++;
	return count;
}


T[] singleArray(T)(T t)
{
	auto ts = new T[1];
	ts[0] = t;
	return ts;
}


size_t[] indicesOf(R, T)(R haystack, T needle)
	if (isInputRange!R)
{
	auto indices = appender!(size_t[])();

	foreach (i, elem; haystack)
	{
		if (elem == needle)
		{
			indices.put(i);
		}
	}

	return indices.data();
}


version(Windows)
{
	import core.sys.windows.windows;

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
}

string getUserSettingsDirectory()
{
	version (Posix)
	{
		static assert(0); // TODO implement
	}
	version (Windows)
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
}

string getSettingsDirectory()
{
	auto path = getUserSettingsDirectory();
	return buildPath(path, "Rossignol");
}

string getUserLanguage()
{
	version (Posix)
	{
	}
	version (Windows)
	{
		setlocale(LC_ALL, "");
		return null;
	}
}