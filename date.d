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

module date;

import std.algorithm;
import std.conv;
import std.datetime;
import std.regex;
import std.string;


int getTZOffset(string tz) @disable
{
	enum tzMap = [
		"UT": 0, "GMT": 0,
		"EST": -500, "EDT": -400,
		"CST": -600, "CDT": -500,
		"MST": -700, "MDT": -600,
		"PST": -800, "PDT": -700,
		"Z": 0, "A": -100, "M": -1200,
		"N": 100, "Y": 1200
	];

	auto found = tz in tzMap;
	if (found)
		return *found;
	else
		return 0;
}

class DateFormatException : Exception
{
public:
	this(string msg)
	{
		super(msg);
	}
}

/**
* Takes a date indication in RFC 822 format and converts it to a 
* SysTime object.
*/
SysTime convertDate(string rfc822Date)
{
	/* Reddite quae sunt Caesaris, Caesari. 
	This pattern was written by Kurt McKee. */
	enum pattern = ctRegex!("(?:(?P<dayname>mon|tue|wed|thu|fri|sat|sun), )?(?P<day> *\\d{1"
							",2}) (?P<month>jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec"
							")(?:[a-z]*,?) (?P<year>(?:\\d{2})?\\d{2})(?: (?P<hour>\\d{2}):"
							"(?P<minute>\\d{2})(?::(?P<second>\\d{2}))? (?:etc/)?(?P<tz>ut|"
							"gmt(?:[+-]\\d{2}:\\d{2})?|[aecmp][sd]?t|[zamny]|[+-]\\d{4}))?", "i");

	enum months = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"];


	auto m = rfc822Date.match(pattern);
	if (m)
	{
		// Parse year 
		int year = to!int(m.captures["year"]);
		if (year < 100) // handle 2 digit year
		{
			if (year < 50 )
				year += 2000;
			else
				year += 1900;
		}

		// parse month
		int month = cast(int)(countUntil(months, m.captures["month"].toLower()) + 1);

		// parse day
		int day = to!int(m.captures["day"]);

		// parse time
		int hour   = to!int(m.captures["hour"]);
		int minute = to!int(m.captures["minute"]);
		int second = to!int(m.captures["second"]);

		// TODO use TZ
		/*string tzText = m.captures["tz"];
		int tzOffset;
		if (!isNumeric(tzText))
		{

		}*/
		return SysTime(DateTime(year, month, day, hour, minute, second));
	}
	else
	{
		throw new DateFormatException("Cannot recognize date format.");
	}
}