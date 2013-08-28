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
import std.utf;
import std.c.locale;

import text;

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

version (linux)
{
    import linux;
}

version(Windows)
{
	import windows;
}

string getUserSettingsDirectory()
{
	version (linux)
	{
		return linux.getUserSettingsDirectory();
	}
	version (Windows)
	{
		return windows.getUserSettingsDirectory();
	}
}

string getApplicationPath()
{
    version (linux)
    {
        return linux.getApplicationPath();
    }
	version (Windows)
	{
		return windows.getApplicationPath();
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

