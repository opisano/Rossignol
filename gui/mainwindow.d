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

module gui.mainwindow;

import core.time;

import std.algorithm;
import std.conv;
import std.exception;
import std.net.curl;
import std.parallelism;
import std.string;

import java.lang.Runnable;

import org.eclipse.swt.SWT;
import org.eclipse.swt.custom.SashForm;
import org.eclipse.swt.events.SelectionAdapter;
import org.eclipse.swt.events.SelectionEvent;
import org.eclipse.swt.graphics.Image;
import org.eclipse.swt.graphics.Point;
import org.eclipse.swt.graphics.Rectangle;
import org.eclipse.swt.layout.FillLayout;
import org.eclipse.swt.widgets.Display;
import org.eclipse.swt.widgets.Event;
import org.eclipse.swt.widgets.Listener;
import org.eclipse.swt.widgets.Tree;
import org.eclipse.swt.widgets.TreeItem;
import org.eclipse.swt.widgets.Menu;
import org.eclipse.swt.widgets.MenuItem;
import org.eclipse.swt.widgets.MessageBox;
import org.eclipse.swt.widgets.Shell;

import feed;
import gui.animation;
import gui.articletable;
import gui.dialogs;
import gui.feedtree;
import properties;
import resources;
import system;

import xml.parser;
import xml.except;

/**
 * Serves as a User Defined Attributes in order to indicate a method in a GUI 
 * action. A GUI action is a method triggered in response to an event such a 
 * a button click or a menu item selection.
 */
enum Action;

/**
 * An adjustable component is a component that can be queried for its 
 * properties. Properties can be set back later.
 */
interface AdjustableComponent
{
	Properties getProperties();
	void setProperties(Properties p);
}

class MainWindow : AdjustableComponent
{
	Shell		 m_shell;
	FeedTree     m_treeFeeds;
	ArticleTable m_tblArticles;
	Menu		 m_fileMenu;
	MenuItem     m_newFeedItem;
	MenuItem     m_newGroup;
	MenuItem     m_refreshAllFeeds;
	MenuItem	 m_exitItem;
	
	ResourceManager m_resMan;

	void loadImages()
	{
		m_resMan = new ResourceManager(getDisplay());
		m_resMan.loadImage("img/16x16/document-new.png", "newfeed");
		m_resMan.loadImage("img/16x16/folder-new.png", "newgroup");
		m_resMan.loadImage("img/rossignol.png", "appicon");
		m_resMan.loadImage("img/16x16/view-refresh.png", "refresh");
		m_resMan.loadImageMap16("img/16x16/process-working.png");
	}

	/**
	 * Method responsible for creating the content of the main window menu bar.
	 */
	void createMenus()
	{
		Menu menuBar = new Menu(m_shell, SWT.BAR);
        MenuItem cascadeFileMenu = new MenuItem(menuBar, SWT.CASCADE);
        cascadeFileMenu.setText("&File");

        m_fileMenu = new Menu(m_shell, SWT.DROP_DOWN);
        cascadeFileMenu.setMenu(m_fileMenu);

		m_newFeedItem = new MenuItem(m_fileMenu, SWT.PUSH);
		m_newFeedItem.setText("&New feed...");
		m_newFeedItem.setImage(m_resMan.getImage("newfeed"));

		m_newGroup = new MenuItem(m_fileMenu, SWT.PUSH);
		m_newGroup.setText("New &group");
		m_newGroup.setImage(m_resMan.getImage("newgroup"));

		new MenuItem(m_fileMenu, SWT.SEPARATOR);

		m_refreshAllFeeds = new MenuItem(m_fileMenu, SWT.PUSH);
		m_refreshAllFeeds.setText("&Refresh all feeds");
		m_refreshAllFeeds.setImage(m_resMan.getImage("refresh"));
		
		new MenuItem(m_fileMenu, SWT.SEPARATOR);

        m_exitItem= new MenuItem(m_fileMenu, SWT.PUSH);
        m_exitItem.setText("&Exit");
        m_shell.setMenuBar(menuBar);

		m_newFeedItem.addSelectionListener(
			new class SelectionAdapter
			{
				override public void widgetSelected(SelectionEvent e)
				{
					newFeedItemAction();
				}
			});

		m_newGroup.addSelectionListener(
			new class SelectionAdapter
			{
				override public void widgetSelected(SelectionEvent e)
				{
					newFeedGroupAction();
				}
			});

		m_refreshAllFeeds.addSelectionListener(
			new class SelectionAdapter
			{
				override public void widgetSelected(SelectionEvent e)
				{
					refreshAllItemsAction();
				}
			});

		m_exitItem.addSelectionListener(
			new class SelectionAdapter
			{
				override public void widgetSelected(SelectionEvent e)
				{
					m_shell.getDisplay().dispose();
				}
			});
	}

	/**
	 * Method responsible for creating the widgets inside the main window 
	 * client area.
	 */
	void createContent()
	{
		m_shell.setLayout(new FillLayout());
		SashForm sform = new SashForm(m_shell, SWT.HORIZONTAL | SWT.SMOOTH);
		m_treeFeeds = new FeedTree(this, sform, SWT.SINGLE | SWT.H_SCROLL | SWT.V_SCROLL);
		m_treeFeeds.loadFromFile();
		m_tblArticles = new ArticleTable(this, sform, SWT.SINGLE | SWT.H_SCROLL | SWT.V_SCROLL);
		sform.setWeights([1, 4]);

		m_shell.addListener(SWT.Close, new class Listener
			{
				override public void handleEvent(Event e)
				{
					try
					{
						m_treeFeeds.saveToFile();
					}
					finally
					{
						m_treeFeeds.dispose();
					}
				}
			});

		m_treeFeeds.addSelectionListener(new class SelectionAdapter
			{
				override public void widgetSelected(SelectionEvent e)
				{
					auto item = cast(TreeItem)e.item;
					selectTreeItemAction(item);
				}
			});
	}

	static shared(FeedInfo) getFeedInfo(string feedURL)
	{
		string xmlContent = assumeUnique(get(feedURL));
		auto parser = new Parser();
		auto handler = new FeedContentHandler(feedURL);
		parser.contentHandler = handler;

		parser.parse(xmlContent);
		return handler.getFeedInfo();
	}


	static void updateTreeItem(TreeItem ti, shared(FeedInfo) fi, ArticleTable table, MultiAnimationThread!TreeItem ath)
	{
		if (ti is null || ti.isDisposed())
		{
			return;
		}

		auto disp = ti.getDisplay();
		if (disp is null || disp.isDisposed())
		{
			return;
		}

		// signal working in background
		disp.syncExec(new class Runnable
					  {
						  public override void run()
						  {
							  if (!ath.isRunning)
								ath.start();
						  }
					  });

		// stop the animation once this function has been terminated.
		scope (exit)
		{
			disp.asyncExec(new class Runnable
						   {
							   public override void run()
							   {
								   ath.remove(ti);
								   if (table.getDisplayedFeed() == fi)
								   {
									   table.refresh();
								   }
							   }
						   });
		}

		auto fi2 = getFeedInfo(fi.getURL());
		size_t newArticlesCount = fi.add(fi2.getArticles());

	}

public:
	this(Display display)
	{
		m_shell = new Shell(display);
		m_shell.setText("Rossignol");

		loadImages();
		createMenus();
		createContent();
		m_shell.setImage(m_resMan.getImage("appicon"));
	}

	void dispose()
	{
		m_shell.dispose();
		m_resMan.dispose();
	}

	/**
	 * GUI action for adding a new feed item
	 */
	@Action
	void newFeedItemAction()
	{
		try
		{
			AddFeedDialog dlg = new AddFeedDialog(m_shell);
			auto groupNames = m_treeFeeds.getGroupNames();
			auto result = dlg.open(groupNames);
			if (result != AddFeedResult.init)
			{
				addFeed(result.url, result.group);
			}
		}
		catch (Exception)
		{
			auto msgbox = new MessageBox(m_shell, SWT.ICON_ERROR | SWT.OK);
			msgbox.setText("Unknown error");
			msgbox.setMessage("An unknown error occured.");
			msgbox.open();
		}
	}

	/**
	 * GUI action for adding a feed group
	 */
	@Action
	void newFeedGroupAction()
	{
		m_treeFeeds.addGroup("NewGroup");
	}

	/**
	 * GUI action for selection of an item in the feed tree.
	 */
	@Action
	void selectTreeItemAction(TreeItem selectedItem)
	{
		if (selectedItem is null)
		{
			return;
		}

		auto feedInfo = m_treeFeeds.getItemFeedInfo(selectedItem);
		if (feedInfo is null)
		{
			return;
		}

		m_tblArticles.setFeedInfo(feedInfo);
	}

	@Action
	void refreshItemAction(TreeItem targetItem)
	{
		if (targetItem is null)
		{
			return;
		}

		auto feedInfo = m_treeFeeds.getItemFeedInfo(targetItem);
		if (feedInfo is null)
		{
			return;
		}

		auto ath = new MultiAnimationThread!(TreeItem)(singleArray(targetItem), dur!"msecs"(50), m_resMan.getImageMap16());
		auto updateTask = task!updateTreeItem(targetItem, feedInfo, m_tblArticles, ath);
		updateTask.executeInNewThread();
	}

	@Action
	void refreshAllItemsAction()
	{
		TreeItem[] items = m_treeFeeds.getFeedItems();
		shared(FeedInfo)[] fis = m_treeFeeds.getFeedInfo(items);
		auto ath = new MultiAnimationThread!TreeItem(items, dur!"msecs"(50), m_resMan.getImageMap16());

		foreach (i; 0..items.length)
		{
			auto updateTask = task!updateTreeItem(items[i], fis[i], m_tblArticles, ath);
			taskPool.put(updateTask);
		}
	}

	/**
	 * Add a feed to the feed list. 
	 *
	 * params:
	 * - feedURL: the URL of the feed to add.
	 * - group: the group the feed will be added to.
	 */
	void addFeed(string feedURL, string group)
	{
		try
		{
			auto feedInfo = getFeedInfo(feedURL);
			m_treeFeeds.addFeed(feedInfo, group);
		}
		catch (SAXParseException e)
		{
			auto msgbox = new MessageBox(m_shell, SWT.ICON_ERROR | SWT.OK);
			msgbox.setText("Parsing error");
			msgbox.setMessage("An error occured while parsing the feed.");
			msgbox.open();
		}
	}

	ResourceManager getResourceManager()
	{
		return m_resMan;
	}

	Properties getProperties()
	{
		Properties props;

		// get the article table properties
		props.addAll(m_tblArticles.getProperties());

		// get main window properties 
		auto size = m_shell.getSize();
		props["MAINWINDOW_WIDTH"] = to!string(size.x);
		props["MAINWINDOW_HEIGHT"] = to!string(size.y);

		// TODO get Sashform weights


		return props;
	}

	void setProperties(Properties props)
	{
		//TODO
	}

	alias m_shell this;
}
