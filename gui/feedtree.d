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

module gui.feedtree;

import std.algorithm;
import std.array;
import std.conv;
import std.exception;
import std.file;
import std.json;
import std.parallelism;
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
import gui.feedtreemodel;
import gui.mainwindow;
import system;



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
 * Asynchronously update a TreeItem icon from an URL.
 * Some feed formats have features to specify a custom icon. This function will
 * fetch the icon from a URL and set it to the TreeItem.
 */

void updateFeedIcon(string imageURL, TreePath path, Tree tree)
{
    immutable(ubyte)[] imageBytes;
    if (imageURL.startsWith("https:"))
    {
        auto http = HTTP();
        http.caInfo("cert/cacert.pem");
        imageBytes = assumeUnique(get!(HTTP, ubyte)(imageURL, http));
    }
    else
    {
        imageBytes = assumeUnique(get!(AutoProtocol, ubyte)(imageURL));
    }

    // this is executed in the gui thread
    tree.getDisplay().asyncExec(new class Runnable
                                  {
                                      void run()
                                      {
                                          TreeItem item = getItemForPath(tree, path);
                                          // Java not knowing about immutable, we must cast immutable away...
                                          auto stream = new ByteArrayInputStream(cast(byte[])imageBytes);
                                          auto feedImage = new Image(tree.getDisplay(), stream);
                                          auto data = cast(FeedNodeData)item.getData();
                                          if (data is null)
                                              return;
                                          item.setImage(feedImage);
                                          data.m_image = feedImage;
                                      }
                                  });
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
            // Add rename menu
            MenuItem mnuRename = new MenuItem(m_popupMenu, 0);
            mnuRename.setText(m_mainWindow.getResourceManager().getText("RENAME"));
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
            
			// Add remove menu
			MenuItem mnuRemove = new MenuItem(m_popupMenu, 0);
            mnuRemove.setText(m_mainWindow.getResourceManager().getText("REMOVE"));
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

		m_imgOpenGroup = mainWindow.getResourceManager().getImage("folderopen");
		m_imgClosedGroup = mainWindow.getResourceManager().getImage("folderclosed");
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
			int index = FeedTreeModel.newGroupIndex(groupNames);

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
            auto updateTask = task!updateFeedIcon(iconUrl, path, m_treeFeeds);
            updateTask.executeInNewThread();			
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
					f.writeln(fi.toXML(feedItem.getText()));
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