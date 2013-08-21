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

module text;

import std.exception;
import std.string;
import std.traits;
import std.utf;


/**
 * strlen-like function that works with any UTF encoding.
 * 
 * wchar_t size in C is not normalized, and is not guaranteed to 
 * be the same as D's wchar. It is easier to rewrite it instead of 
 * checking for wcslen and co.
 */
size_t slen(T)(const(T)* str) pure nothrow
	if (isSomeChar!T)
in
{
	assert (str !is null);
}
body
{
	size_t count;
	while (*str++)
		++count;
	return count;
}

unittest
{
	auto s = "Songe d'une nuit d'été";
	assert(slen(toStringz(s)) == 24);

	auto s2 = "La nuit des temps"w;
	assert(slen(toUTF16z(s2)) == 17);
}

/**
 * Returns wether a code unit is the first code unit of a sequence.
 */
@safe bool isFirst(char c) pure nothrow
{
	return (c < 128) || ((c & 0b0100_0000) != 0);
}

/**
 * Returns the length in bytes of a UTF-8 sequence starting by the
 * char passed in parameter.
 */
@safe size_t codeLength(char c) pure
out (result)
{
	assert (result > 0 && result < 5);
}
body
{
	if (!isFirst(c) || c == 0xC0 || c == 0xC1 || c > 244)
	{
		throw new UTFException("Illegal UTF-8 starting code unit.");
	}

	if (c < 128)
	{
		return 1;
	}
	else
	{
		size_t count = 2;
		ubyte word = cast(ubyte)(c << 2);
		while (word & 0b1000_0000)
		{
			++count;
			word <<= 1;
		}
		return count;
	}
}

unittest
{
	// test 1 byte sequences
	foreach (char i; 0..128)
	{
		assert(codeLength(i) == 1);
	}

	// test 2 byte sequences
	foreach (char i; 194..224)
	{
		assert(codeLength(i) == 2);
	}

	// test 3 byte sequences
	foreach (char i; 224..240)
	{
		assert(codeLength(i) == 3);
	}

	// test 4 byte sequences
	foreach (char i; 240..245)
	{
		assert(codeLength(i) == 4);
	}

	// Test invalid input
	foreach (char i; 128..194)
	{
		assertThrown!UTFException(codeLength(i));
	}
	foreach (i; 245..256)
	{
		assertThrown!UTFException(codeLength(cast(char)i));
	}
}

/**
 * This function acts the same as std.range.take() but
 * cares not to split the string in the middle of a multibyte 
 * sequence (which would produce an invalid UTF-8 sequence later on).
 */
string take(string src, size_t units)
in
{
	assert (src !is null);
}
out (result)
{
	assert (result.length <= src.length);
	assert (result.length <= units);
	assertNotThrown!UTFException(validate(result));
}
body
{
	if (src.length < units)
	{
		return src;
	}
	else
	{
		// start at src[units-1] and go back as long 
		// as we are in the middle of a code point
		size_t index = units-1;
		while (!isFirst(src[index]) 
				|| codeLength(src[index]) > (units-index))
		{
			--index;
		}
		index += codeLength(src[index]);
		return src[0..index];
	}
}

unittest
{
	auto s = "Ma chérie";
	assert (take(s, 6)  == "Ma ch");
}