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

module gui.feedtreemodel;

import std.algorithm;
import std.array;
import std.conv;
import std.range;
import std.regex;

import org.eclipse.swt.graphics.Image;
import org.eclipse.swt.widgets.Tree;
import org.eclipse.swt.widgets.TreeItem;

import feed;
import system;

/*----------------------------------------------------------------------------*
*                                                                            *
*    Node Data                                                               *
*                                                                            *
* TreeNodeData subclasses are placed in TreeItem instances via the setData() *
* method. They serve as a unified interface for storing and retrieving info  *
* about what is represented by the TreeItem (either a group or a feed)       *
*                                                                            *
*----------------------------------------------------------------------------*/

/**
* Abstract common class for storing data in the nodes 
* of a feed tree.
*/
package abstract class TreeNodeData
{
	/**
    * Identifies if the node is a group
    */
	abstract bool isGroup() const nothrow;

	/**
    * Releases all the non-managed resources stored.
    */
	void dispose() 	{ }
}

/**
* Class for storing data about a group node
*/
package final class GroupNodeData : TreeNodeData
{
	bool m_defaultGroup; // is this group the default group ?

public:
	/**
    * Constructs a GroupNodeData object.
    *
    * params:
    * unclassified = flag for controling if we are building the default group.
    */
	this(bool defaultGroup = false)
	{
		m_defaultGroup = defaultGroup;
	}

	override bool isGroup() const nothrow
	{
		return true;
	}

	/**
    * Says if this group is the default group or not.
    */
	bool isDefaultGroup() const nothrow
	{
		return m_defaultGroup;
	}
}

/**
* Stores information about feed node.
*/
package final class FeedNodeData : TreeNodeData
{
	// the FeedInfo object 
	shared FeedInfo m_feedInfo;
	Image    m_image;

public:
	/**
	* Constructs a FeedNodData object.
	*
	* params:
	* fi = The FeedInfo object we are dealing with.
	*/
	this(shared FeedInfo fi)
	{
		m_feedInfo = fi;
	}

	override bool isGroup() const nothrow
	{
		return false;
	}

	/**
    * Returns this node feed.
    */
	shared(FeedInfo) getFeedInfo()
	{
		return m_feedInfo;
	}

	override void dispose()
	{
		if (m_image !is null)
		{
			m_image.dispose();
		}
	}
}

package final class FeedTreeModel
{

package:
    /**
    * Returns the index of the group name suffix to use when 
    * creating a new group.
    * When creating a new group, the UI assign it a default name
    * ("NewGroup"). If this name is already in the Tree, a numerical
    * suffix is used ("NewGroup1", "NewGroup2", etc).
    * This function returns the suffix to use for the next group.
    *
    * Params:
    * groupNames = name of all the groups
    * groupName = provides a way of changing the default name of a group.
    */
	static int newGroupIndex(R)(R groupNames, string groupName = "NewGroup")
	{
		auto pattern = regex("^" ~ groupName ~ `(?P<index>\d*)$`);
		int result = 0;

		// For each group name
		foreach (name; groupNames)
		{
			// compare name text to the pattern
			auto m = match(name, pattern);
			if (m)
			{
				// if match has a numerical suffix 
				if (!m.captures["index"].empty)
				{
					int matchIndex;
					try
					{
						matchIndex = to!int(m.captures["index"]);
					}
					catch (ConvException e)
					{
						// prevent conversion error to show up
					}

					if (matchIndex >= result)
						result  = matchIndex + 1;
				}
				// else if match has no numerical suffix and is the first one found
				else if (result == 0)
				{
					result = 1;
				}
			}
		}
		return result;
	}

    unittest 
	{
		assert (newGroupIndex(["Informatique", "NewGroup", "Équitation"]) == 1);
		assert (newGroupIndex(["Informatique", "NewGroup", "Équitation", "NewGroup1"]) == 2);
		assert (newGroupIndex(["Informatique", "NewGroup", "Équitation", "NewGroup41"]) == 42);
	}
}

/**
* Modelizes a path through a Tree
*/
package struct TreePath
{
	string[]  path;

	/**
    * Serializes a TreePath into an array of bytes
    */
	string serialize()
	{
		return path.join("/");
	}

	unittest
	{
		TreePath p;
		p.path = ["ABC", "DE", "FG"];
		string bytes = p.serialize();
		assert (bytes == "ABC/DE/FG");
	}

	/**
    * Deserializes a TreePath from an array of bytes
    */
	static TreePath deserialize(byte[] data)
	{
		enum SEPARATOR = 47; // '/'

		ubyte[] ub = cast(ubyte[])data;
		// number of components
		size_t[] indices = indicesOf(data, cast(ubyte)SEPARATOR);

		TreePath tp;
		tp.path = new string[indices.length + 1];

		size_t from;
		size_t i;
		foreach (to; indices)
		{
			tp.path[i] = cast(string)(ub[from..to].idup);
			from = to + 1;
			++i;
		}

		tp.path[i] = cast(string)(ub[from..$].idup);

		return tp;
	}

	unittest
	{
		TreePath p  = TreePath.deserialize([65, 66, 67, 47, 68, 69, 47, 70, 71]);
		assert (p.path == ["ABC", "DE", "FG"]);
	}
}

/**
* Returns the path for an item
*/
package TreePath treePath(TreeItem item)
{
	auto buffer = appender!(string[])();

	// move up the tree to the root
	while (item !is null)
	{
		buffer ~= item.getText();
		item = item.getParentItem();
	}

	TreePath tp;
	tp.path = buffer.data().retro().array(); // invert the 

	return tp;
}

/**
* Returns the TreeItem from a path.
*/
package TreeItem getItemForPath(Tree tree, TreePath path)
{
	TreeItem getItemForPathImpl(TreeItem[] treeItems, string[] path)
	{
		auto r = find!(x => x.getText() == path[0])(treeItems);
		if (r.empty)
		{
			return null;
		}
		else
		{
			path = path[1..$];
			if (path.empty)
			{
				return r.front;
			}
			else
			{
				return getItemForPathImpl(r.front.getItems(), path);
			}
		}
	}

	return getItemForPathImpl(tree.getItems(), path.path);
}
