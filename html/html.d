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

module html.html;

import std.array;
import std.string;

string htmlToText(string htmlContent)
{
    auto buffer = appender!string();

	auto openTagIndex = htmlContent.indexOf('<');
    while (openTagIndex != -1 && !htmlContent.empty)
    {
        buffer.put(htmlContent[0..openTagIndex]);
        auto closeTagIndex = htmlContent[openTagIndex+1..$].indexOf('>');
        
        if (closeTagIndex != -1)
        {
            closeTagIndex += openTagIndex+1;
            htmlContent = htmlContent[closeTagIndex+1..$];
        }
        else
        {
            break;
        }
        openTagIndex = htmlContent.indexOf('<');
    }

    if (buffer.data().empty)
    {
        return htmlContent;
    }
    else
    {
        return buffer.data();
    }
}

unittest
{
    string orig = "<p>Hello, <b>Dolly</b>, will you look at this image ? <img src=\"../img/dolly.jpg\"/>";
    string expected = "Hello, Dolly, will you look at this image ? ";

    auto result = htmlToText(orig);
    assert (result == expected);
}
