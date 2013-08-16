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

module xml.attributes;

import std.algorithm;
import std.exception;
import std.functional;
import std.typetuple;

import xml.except;

enum AttributeType
{
	CDATA,
	ID,
	IDREF,
	IDREFS,
	NMTOKEN,
	NMTOKENS,
	ENTITY,
	ENTITIES,
	NOTATION
}

struct Attribute
{
	string			namespace;
	string			localName;
	string			value;
	AttributeType	type;
}

string name_(const ref Attribute attr)
{
	if (attr.namespace is null)
		return attr.localName;
	else 
		return attr.namespace ~ ":" ~ attr.localName;
}

alias memoize!name_ name;

struct Attributes
{
	Attribute[] attrs;

	/** Look up the index of an attribute by XML qualified (prefixed name.)*/
	ptrdiff_t getIndex(string qName) const 
	{
		return countUntil!((attr, n) => attr.name() == n)(attrs, qName);
	}

	/** Look up the index of an attribute by namespace name. */
	ptrdiff_t getIndex(string uri, string localname) const
	{
		string[2] range;
		range[0] = uri;
		range[1] = localname;

		return countUntil!((attr, r) => attr.namespace == r[0] 
						   && attr.localName == r[1])(attrs, range[]);
	}

	@property size_t length() const { return attrs.length; }

	/** Look up an attribute's local name by index. */
	string getLocalName(size_t index) const
	{
		return attrs[index].localName;
	}

	string getQName(size_t index) const
	{
		return attrs[index].name();
	}

	AttributeType getType(size_t index) const
	{
		return attrs[index].type;
	}

	AttributeType getType(string qName) const
	{
		auto index = getIndex(qName);
		if (index == -1)
			throw new SAXException("Attribute not found");

		return getType(index);
	}

	AttributeType getType(string uri, string localName) const
	{
		auto index = getIndex(uri, localName);
		if (index == -1)
			throw new SAXException("Attribute not found");
		return getType(index);
	}

	string getURI(size_t index) const
	{
		return attrs[index].namespace;
	}

	string getValue(size_t index) const
	{
		return attrs[index].value;
	}

	string getValue(string qName) const
	{
		auto index = getIndex(qName);
		if (index == -1)
			throw new SAXException("Attribute not found");

		return getValue(index);
	}

	string getValue(string uri, string localName) const
	{
		auto index = getIndex(uri, localName);
		if (index == -1)
			throw new SAXException("Attribute not found");
		return getValue(index);
	}
}