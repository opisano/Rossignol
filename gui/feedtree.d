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

module gui.feedtree;

import core.thread;

import std.algorithm;
import std.array;
import std.conv;
import std.exception;
import std.file;
import std.json;
import std.path;
import std.range;
import std.regex;
import std.stdio;
import std.string;

import std.net.curl;

import java.io.ByteArrayInputStream;
import java.lang.Runnable;
import java.lang.wrappers;

import org.eclipse.swt.SWT;
import org.eclipse.swt.custom.TreeEditor;
import org.eclipse.swt.dnd.DND;
import org.eclipse.swt.dnd.DragSource;
import org.eclipse.swt.dnd.DragSourceEvent;
import org.eclipse.swt.dnd.DragSourceListener;
import org.eclipse.swt.dnd.DropTarget;
import org.eclipse.swt.dnd.DropTargetAdapter;
import org.eclipse.swt.dnd.DropTargetEvent;
import org.eclipse.swt.dnd.TextTransfer;
import org.eclipse.swt.dnd.Transfer;
import org.eclipse.swt.events.FocusAdapter;
import org.eclipse.swt.events.FocusEvent;
import org.eclipse.swt.events.KeyAdapter;
import org.eclipse.swt.events.KeyEvent;
import org.eclipse.swt.events.MouseAdapter;
import org.eclipse.swt.events.MouseEvent;
import org.eclipse.swt.events.SelectionAdapter;
import org.eclipse.swt.events.SelectionEvent;
import org.eclipse.swt.graphics.Image;
import org.eclipse.swt.graphics.Point;
import org.eclipse.swt.widgets.Composite;
import org.eclipse.swt.widgets.Display;
import org.eclipse.swt.widgets.Menu;
import org.eclipse.swt.widgets.MenuItem;
import org.eclipse.swt.widgets.Text;
import org.eclipse.swt.widgets.Tree;
import org.eclipse.swt.widgets.TreeItem;

import feed;
import gui.mainwindow;
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
private abstract class TreeNodeData
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
private final class GroupNodeData : TreeNodeData
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
private final class FeedNodeData : TreeNodeData
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

/*----------------------------------------------------------------------------*
 *                                                                            *
 *    Tree Paths                                                              *
 *                                                                            *
 * Contrary to Swing's JTree, SWT Tree component does not provide a easy way  *
 * to represent a path through a tree, node by node. The purpose of the       *
 * following structure and functions is to fill this need.                    *
 *                                                                            *
 *----------------------------------------------------------------------------*/

/**
 * Modelizes a path through a Tree
 */
private struct TreePath
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
private TreePath treePath(TreeItem item)
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
private TreeItem getItemForPath(Tree tree, TreePath path)
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

/**
 * Class responsible for asynchronously update a feed icon 
 * from its URL.
 *
 * TODO : see if I can replace this by a std.parallelism-based solution.
 */
class UpdateFeedIconThread : core.thread.Thread
{
	string m_imageURL;
	TreePath m_path;
	Tree     m_tree;

	void run()
	{
		// Only this line is executed in this thread
		auto imageBytes = assumeUnique(get!(AutoProtocol, ubyte)(m_imageURL));

		// this is executed in the gui thread
		m_tree.getDisplay().asyncExec(new class Runnable
			{
				void run()
				{
					TreeItem item = getItemForPath(m_tree, m_path);
					// Java not knowing about immutable, we must cast immutable away...
					auto stream = new ByteArrayInputStream(cast(byte[])imageBytes);
					auto feedImage = new Image(m_tree.getDisplay(), stream);
					auto data = cast(FeedNodeData)item.getData();
					if (data is null)
						return;
					item.setImage(feedImage);
					data.m_image = feedImage;
				}
			}
		);
	}

public:
	this(string imageURL, TreePath path, Tree tree)
	{
		super(&run);
		m_imageURL = imageURL;
		m_path = path;
		m_tree = tree;
	}
}


bool isFeedNode(TreeItem item)
{
	if (item is null)
		return false;

	if (item.getItemCount() > 0)
		return false;

	FeedNodeData data = cast(FeedNodeData) item.getData();
	return (data !is null);
}

bool isGroupNode(TreeItem item)
{
	if (item is null)
		return false;

	GroupNodeData data = cast (GroupNodeData) item.getData;
	return (data !is null);
}

/*----------------------------------------------------------------------------*
 *                                                                            *
 *    Drag and drop                                                           *
 *                                                                            *
 * The DragSourceManager and DropTargetManager classes provide support for    *
 * moving a Feed item from a group to another by dragging or dropping.        *
 *                                                                            *
 *----------------------------------------------------------------------------*/

/**
 * Respond to drag events in a Tree instance
 */
private final class DragSourceManager : DragSourceListener
{
	FeedTree m_tree;
public
	this(FeedTree tree)
	{
		m_tree = tree;
	}

	/**
     * When the user initiate a drag action.
     */
	void dragStart(DragSourceEvent event)
	{
		// get tree selected item
		TreeItem[] selectedItems = m_tree.getSelection();

		// Only accept dragging Feed items.
		if (selectedItems.length > 0 && isFeedNode(selectedItems[0]))
		{
			event.doit = true;
			m_tree.m_dragSourceItem = selectedItems[0];
		}
		else
		{
			event.doit = false;
		}
	}

	/**
	 * When SWT needs data about the item being dnd'ed
	 */
	void dragSetData(DragSourceEvent event)
	{
		// if SWT asks for textual data, provide the TreePath to the item.
		if (TextTransfer.getInstance().isSupportedType(event.dataType))
		{
			assert (m_tree.m_dragSourceItem !is null);
			auto path = treePath(m_tree.m_dragSourceItem);
			event.data = stringcast(path.serialize());
		}
	}

	/**
	 * When the drag&drop is over
	 */
	void dragFinished(DragSourceEvent event)
	{
		// Did it end with a move ?
		if (event.detail == DND.DROP_MOVE)
		{
			// then remove the source item.
			m_tree.m_dragSourceItem.dispose();
			m_tree.m_dragSourceItem = null;
		}
	}
}

/**
 * Responds to drop events in a Tree instance.
 */
private final class DropTargetManager : DropTargetAdapter
{
	FeedTree m_tree;

public:
	this(FeedTree tree)
	{
		m_tree = tree;
	}

	/**
	 * When the mouse passes over the Tree.
	 */
	override void dragOver(DropTargetEvent event)
	{
		event.feedback = DND.FEEDBACK_EXPAND | DND.FEEDBACK_SCROLL;

		// If there is an item underneath
		if (event.item !is null)
		{
			event.feedback |= DND.FEEDBACK_SELECT;

			// only accept drop if the item under the mouse cursor is a group
			TreeItem item = cast(TreeItem)event.item;
			if (! isGroupNode(item))
			{
				event.detail = DND.DROP_NONE;
			}
			else
			{
				event.detail = DND.DROP_MOVE;
			}
		}
	}

	/**
	 * When the user drops something on the Tree. 
	 */
	override void drop(DropTargetEvent event)
	{
		// get source item
		TreeItem srcItem = m_tree.m_dragSourceItem;

		// only accepts Feed items as source
		if (srcItem is null || !isFeedNode(srcItem))
		{
			event.detail = DND.DROP_NONE;
			return;
		}

		// only accept group items as destination
		TreeItem grpItem = cast(TreeItem)event.item;
		if (grpItem is null || !isGroupNode(grpItem))
		{
			event.detail = DND.DROP_NONE;
			return;
		}

		// create a new item inside the group and move source item to it.
		auto dstItem = new TreeItem(grpItem, SWT.NONE);
		m_tree.move(srcItem, dstItem);
	}
}

/**
 * Class responsible for managing a hierarchy of feeds in a graphical user interface.
 */
class FeedTree
{
	// the underlying SWT Tree widget
	Tree        m_treeFeeds;
	// used for renaming TreeItem objects
	TreeEditor  m_editor;
	// Image of an open group
	Image       m_imgOpenGroup;
	// Image of a close group
	Image       m_imgClosedGroup;
	// Default image of a feed
	Image       m_imgFeedDefault;
	// Node data shared for all the non-default groups
	GroupNodeData m_groupNodeData;
	// popup menu (displayed when right-click the Tree)
	Menu        m_popupMenu;

	TreeItem    m_dragSourceItem;

	MainWindow m_mainWindow;

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

	/** 
	 * Creates the unclassified feeds group node
	 */
	void addUnclassifiedGroup(string groupName)
	{
		auto item = new TreeItem(m_treeFeeds, 0);
		m_treeFeeds.setSelection(item);
		item.setText(groupName);
		item.setImage(m_imgClosedGroup);
		item.setData(new GroupNodeData(true));
	}

	/**
	 * Populates the content of the popup menu contextually, 
	 * depending on the nature of the TreeItem the user right-clicked on.
	 */
	void populatePopupMenu(TreeNodeData data)
	{
		// Clear previous popup menu
		foreach (item; m_popupMenu.getItems())
		{
			item.dispose();
		}

		if (data is null)
		{

		}
		else
		{
			// Add remove menu
			MenuItem mnuRemove = new MenuItem(m_popupMenu, 0);
			mnuRemove.setText("Remove");
			mnuRemove.addSelectionListener(new class SelectionAdapter
				{
					override public void widgetSelected(SelectionEvent e)
					{
						// get the selected tree item
						int selectedCount = m_treeFeeds.getSelectionCount();
						if (selectedCount < 1)
						{
							return;
						}
						TreeItem selectedItem = m_treeFeeds.getSelection()[0];

						deleteNode(selectedItem);
					}
				});
			if (data.isGroup())
			{
                // Add rename menu
                MenuItem mnuRename = new MenuItem(m_popupMenu, 0);
                mnuRename.setText("Rename");
                mnuRename.addSelectionListener(
                    new class SelectionAdapter
                    {
                        override public void widgetSelected(SelectionEvent e)
                        {
                            // get the selected tree item
                            int selectedCount = m_treeFeeds.getSelectionCount();
                            if (selectedCount < 1)
                            {
                                return;
                            }
                            TreeItem selectedItem = m_treeFeeds.getSelection()[0];

                            renameNode(selectedItem);
                        }
                    });


				auto groupData = cast(GroupNodeData)data;
				// Disable remove for the default group
				if (groupData.isDefaultGroup())
				{
					mnuRemove.setEnabled(false);
				}

				MenuItem mnuNewFeed = new MenuItem(m_popupMenu, 0);
				mnuNewFeed.setText("&New feed...");
				mnuNewFeed.addSelectionListener(new class SelectionAdapter
					{
						override public void widgetSelected(SelectionEvent e)
						{
							m_mainWindow.newFeedItemAction();
						}
					});
			}
			else
			{
				MenuItem mnuRefresh = new MenuItem(m_popupMenu, 0);
				mnuRefresh.setText("&Refresh");
				mnuRefresh.addSelectionListener(new class SelectionAdapter
					{
						override public void widgetSelected(SelectionEvent e)
						{
							// get the selected tree item
							int selectedCount = m_treeFeeds.getSelectionCount();
							if (selectedCount < 1)
							{
								return;
							}
							TreeItem selectedItem = m_treeFeeds.getSelection()[0];

							m_mainWindow.refreshItemAction(selectedItem);
						}
					});
			}
		}
	}

	/**
	 * Apply a function to all the Feed nodes. 
	 * 
	 * params:
	 * fun: alias of a function to call of each FeedNode. the prototype of this function is
	 *      void fun(TreeItem). 
	 *
	 * TODO: When DMD bug #3051 is fixed, change to an template function taking a function by alias.
	 *
	 */
	void mapFeeds(void delegate(TreeItem ti) fun)
	{
		auto groups = m_treeFeeds.getItems();
		foreach (group; groups)
		{
			auto children = group.getItems();
			
			debug
			{   // check all the children are feed nodes
				auto nonFeedFound = find!((item) => (cast(TreeNodeData)item.getData()) is null && item.getItems().length == 0)(children);
				assert (nonFeedFound.empty);
			}

			foreach (child; children)
			{
				fun(child);
			}
		}
	}

	/**
	 * Transfers the ownership of ressources from one TreeItem instance to another.
	 */
	void move(TreeItem src, TreeItem dst)
	in 
	{
		assert (src !is null);
		assert (dst !is null);
	}
	body
	{
		dst.setData(src.getData());
		dst.setImage(src.getImage());
		dst.setText(src.getText());
		src.setData(null);
		src.setImage(cast(Image)null);
	}

public:
	static this()
	{
		version (Windows)
		{
			Image.globalDisposeChecking = false;
		}
	}

	this(MainWindow mainWindow, Composite parent, int style)
	{
		m_mainWindow = mainWindow;
		m_treeFeeds = new Tree(parent, style);

		// Drag and drop init
		Transfer[] types = [ TextTransfer.getInstance() ];
		auto source = new DragSource(m_treeFeeds, DND.DROP_MOVE);
		source.setTransfer(types);
		source.addDragListener(new DragSourceManager(this));

		auto target = new DropTarget(m_treeFeeds, DND.DROP_MOVE);
		target.setTransfer(types);
		target.addDropListener(new DropTargetManager(this));

		m_editor = new TreeEditor(m_treeFeeds);
		m_editor.horizontalAlignment = SWT.LEFT;
		m_editor.grabHorizontal = true;

		m_imgOpenGroup = new Image(m_treeFeeds.getDisplay(), "img/16x16/folder-open.png");
		m_imgClosedGroup = new Image(m_treeFeeds.getDisplay(), "img/16x16/folder.png");
		m_imgFeedDefault = mainWindow.getResourceManager().getImage("feed");
		m_groupNodeData = new GroupNodeData(false);

		addUnclassifiedGroup("Unclassified feeds");

		m_popupMenu = new Menu(m_treeFeeds);

		m_treeFeeds.addMouseListener(new class MouseAdapter
			{
				override public void mouseUp(MouseEvent e)
				{
					if (e.button == 3) // right-click
					{
						auto pt = m_treeFeeds.getDisplay().getCursorLocation();

						// get TreeItem at position (e.x, e.y) and select it
						Point relativePt = new Point(e.x, e.y);
						auto item = m_treeFeeds.getItem(relativePt);
						TreeNodeData data;
						if (item !is null)
						{
							data = cast(TreeNodeData) item.getData();
						}
						populatePopupMenu(data);
						m_popupMenu.setLocation(pt.x, pt.y);
						m_popupMenu.setVisible(true);
					}
				}
			});
	}

	void dispose()
	{
		mapFeeds((item) => (cast(TreeNodeData)item.getData()).dispose());
		m_treeFeeds.dispose();
	}

	alias m_treeFeeds this;

	/**
	 * Modifies the UI to enable the user to rename a node in the tree.
	 *
	 * Params:
	 * item = The item the user wants to rename.
	 *
	 */
	void renameNode(TreeItem item)
	{
		/** checks a name is correct for a node */
		bool validateNodeName(string text)
		{
			enum forbidden = ['/', '\\', '?', '%', 
			                  '*', ':', '|', '"',
			                  '<', '>', '.'];
			foreach (c; text)
			{
				auto index = forbidden.countUntil(c);
				if (index != -1)
				{
					return false;
				}
			}
			return true;
		}

		auto text = new Text(m_treeFeeds, SWT.BORDER);
		text.setText(item.getText);
		text.selectAll();
		text.setFocus();

		text.addFocusListener(new class FocusAdapter
			{
				override public void focusLost(FocusEvent e)
				{
					item.setText(text.getText());
					text.dispose();
				}
			});

		text.addKeyListener(new class KeyAdapter
			{
				override public void keyPressed(KeyEvent e)
				{
					if (e.keyCode == SWT.CR)
					{
						if (validateNodeName(text.getText()))
						{
							item.setText(text.getText());
						}
						text.dispose();
					}
					else if (e.keyCode == SWT.ESC)
					{
						text.dispose();
					}
				}
			});
		m_editor.setEditor(text, item);
	}

	void deleteNode(TreeItem item)
	{
		TreeNodeData nodeData = cast(TreeNodeData)item.getData();
		if (nodeData.isGroup())
		{
			GroupNodeData groupData = cast(GroupNodeData)nodeData;
			if (groupData.isDefaultGroup())
			{
				// cannot delete the default group
				return;
			}

			auto children = item.getItems();
			foreach (child; children)
			{
				deleteNode(child);
			}
		}
		item.setData(null);
		item.dispose();
	}

	/**
	 * Adds a group to this Tree.
	 *
	 * params:
	 * groupName = the name of this group.
	 * 
	 */
	void addGroup(string groupName, bool defaultName = true)
	{
		if (defaultName)
		{
			// Get all the group names
			auto groupNames = getGroupNames();
			// get the suffix to use
			int index = newGroupIndex(groupNames);

			if (index != 0)
			{
				groupName ~= to!string(index);
			}
		}

		// create a node for the new group
		auto item = new TreeItem(m_treeFeeds, 0);
		m_treeFeeds.setSelection(item);
		item.setText(groupName);
		item.setImage(m_imgClosedGroup);
		item.setData(m_groupNodeData);

		// give the user the opportunity to change the group name
		if (defaultName)
		{
			renameNode(item);
		}
	}

	/**
	 * Returns an InputRange of strings of all the group names in this tree.
	 */
	auto getGroupNames()
	{
		return map!((item) => item.getText())(m_treeFeeds.getItems());
	}

	void addFeed(shared FeedInfo fi, string groupName)
	{
		// find the group item whose text matches groupName
		auto groups = m_treeFeeds.getItems();
		auto found = find!((item, text) => item.getText() == text)(groups, groupName);
		assert (found.empty == false);

		auto groupItem = found.front;
		auto feedItem = new TreeItem(groupItem, 0);
		feedItem.setText(fi.getName());
		feedItem.setData(new FeedNodeData(fi));

		if (!groupItem.getExpanded())
		{
			groupItem.setExpanded(true);
		}
		m_treeFeeds.setSelection(feedItem);
		feedItem.setImage(m_imgFeedDefault);

        string iconUrl = fi.getIcon();
		if (!iconUrl.empty)
		{
            // if relative url, translate to absolute URL
            if (iconUrl.startsWith('/'))
            {
                // extract site root from link
                string base = fi.getLink();
                if (base.startsWith("http://"))
                {
                    base = base[7..$];
                }
                else if (base.startsWith("https://"))
                {
                    base = base[8..$];
                }

                auto index = std.string.indexOf(base, '/');
                if (index != -1)
                {
                    base = base[0..index];
                }

                iconUrl = base ~ iconUrl;
            }

			auto path = treePath(feedItem);
			auto th = new UpdateFeedIconThread(iconUrl, path, m_treeFeeds);
			th.start();
		}
	}

	/**
	 * Returns the Feed information associated with a TreeItem.
	 */
	shared(FeedInfo) getItemFeedInfo(TreeItem item)
	in
	{
		assert (item !is null);
	}
	body
	{
		FeedNodeData data = cast(FeedNodeData) item.getData();
		if (data is null)
		{
			return null;
		}

		return data.getFeedInfo();
	}

	void saveToFile()
	{
		// get feed directory
		auto feedDir = buildPath(getSettingsDirectory(), "feeds");
		if (!feedDir.exists())
		{
			feedDir.mkdirRecurse();
		}

		// rename any existing .xml file by adding a ".bak" suffix 
		foreach (entry; dirEntries(feedDir, SpanMode.shallow))
		{
			if (entry.name.endsWith(".xml"))
			{
				rename(entry.name, entry.name ~ ".bak");
			}
		}

		// In case of future error in this function
		scope (failure)
		{
			foreach (entry; dirEntries(feedDir, SpanMode.shallow))
			{
				// delete any .xml file
				if (entry.name.endsWith(".xml"))
				{
					remove(entry.name);
				}
				//  and rename .xml.bak files to .xml
				else if (entry.name.endsWith(".xml.bak"))
				{
					rename(entry.name, entry.name[0..$-4]);
				}
			}
		}

		// If this function completes successfully
		scope (success)
		{
			// delete any .xml.bak file
			foreach (entry; dirEntries(feedDir, SpanMode.shallow))
			{
				if (entry.name.endsWith(".xml.bak"))
				{
					remove(entry.name);
				}
			}
		}


		foreach (groupItem; m_treeFeeds.getItems())
		{
			auto filename = buildPath(feedDir, groupItem.getText() ~ ".xml");
			auto f = File(filename, "w");
			f.writeln("<?xml version=\"1.1\" encoding=\"UTF-8\" ?>");
			f.writeln("<group>");
			foreach (feedItem; groupItem.getItems())
			{
				auto data = cast(FeedNodeData)feedItem.getData();
				if (data !is null)
				{
					auto fi = data.getFeedInfo();
					f.writeln(fi.toXML());
				}
			}
			f.write("</group>\n");
		}
	}

	void loadFromFile()
	{
		// get feed directory
		auto feedDir = buildPath(getSettingsDirectory(), "feeds");
		if (!feedDir.exists())
		{
		    mkdirRecurse(feedDir);
		}

		// for each xml file in feed directory
		foreach (entry; dirEntries(feedDir, SpanMode.shallow))
		{
			if (!entry.name.endsWith(".xml"))
			{
			    continue;
			}
				
			auto groupName = baseName(stripExtension(entry.name));

			// look for the corresponding group TreeItem 
			auto found = m_treeFeeds.getItems().find!((a,b) => a.getText() == b)(groupName);
			TreeItem groupItem;
			if (!found.empty)
			{
				groupItem = found.front;
			}
			else // or create it
			{
				groupItem = new TreeItem(m_treeFeeds, 0);
				groupItem.setText(groupName);
				groupItem.setImage(m_imgClosedGroup);
				groupItem.setData(m_groupNodeData);
			}

			// deserialize FeedInfo objects from XML
			auto feedInfos = loadFeedsFromXML(entry.name);
			foreach (feedInfo; feedInfos)
			{
				addFeed(feedInfo, groupName);
			}
		}
	}

	size_t getFeedCount()
	{
		size_t count;
		foreach (groupItem; m_treeFeeds.getItems())
		{
			debug
			{	// check all the children are feeds
				foreach (feedItem; groupItem.getItems())
				{
					auto fnd = cast(FeedNodeData)feedItem.getData();
					assert (fnd !is null);
				}
			}

			count += groupItem.getItemCount();
		}

		return count;
	}

	/**
	 * Return an array of TreeItems that contain feed information.
	 */
	TreeItem[] getFeedItems()
	{
		auto itemCount = getFeedCount();
		auto items = new TreeItem[itemCount];
		size_t index;

		foreach (groupItem; m_treeFeeds.getItems())
		{
			foreach (feedItem; groupItem.getItems())
			{
				items[index++] = feedItem;
			}
		}

		return items;
	}

	/**
	 * Returns an array of feed information from treeitems.
	 * The tree items must have been obtained through a call 
	 * to getFeedItems() for this instance of FeedTree.
	 */
	shared(FeedInfo)[] getFeedInfo(TreeItem[] items)
	in
	{
		foreach (item; items)
		{
			// check each item belong to this tree
			assert (item.getParent() is m_treeFeeds);
			// check each item is a Feed (not a group).
			assert ((cast(FeedNodeData)item.getData()) !is null);
		}
	}
	out(result)
	{
		// 
		assert(result.length == items.length);
		foreach (i; 0..result.length)
		{
			assert((cast(FeedNodeData)items[i].getData()).getFeedInfo is result[i]);
		}
	}
	body
	{
		auto fis = new shared(FeedInfo)[items.length];
		foreach (i, item; items)
		{
			fis[i] = (cast(FeedNodeData)items[i].getData()).getFeedInfo();
		}

		return fis;
	}

	void setFeedInfo(TreeItem item, shared(FeedInfo) info)
	in
	{
		assert (item.getParent is m_treeFeeds);
		assert (item.getItems().length == 0);
		Object obj = item.getData();
		if (obj !is null)
		{
			assert((cast(TreeNodeData)(obj)).isGroup() == false);
		}
	}
	body
	{
		FeedNodeData data = new FeedNodeData(info);
		item.setData(data);
	}
}