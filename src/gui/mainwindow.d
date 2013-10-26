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

module gui.mainwindow;

import std.algorithm;
import std.conv;
import std.exception;
import std.file;
import std.net.curl;
import std.parallelism;
import std.path;
import std.stdio;
import std.string;

import std.c.time;

import java.lang.Runnable;

import org.eclipse.swt.SWT;
import org.eclipse.swt.custom.SashForm;
import org.eclipse.swt.events.SelectionAdapter;
import org.eclipse.swt.events.SelectionEvent;
import org.eclipse.swt.graphics.Image;
import org.eclipse.swt.graphics.Point;
import org.eclipse.swt.graphics.Rectangle;
import org.eclipse.swt.layout.GridData;
import org.eclipse.swt.layout.GridLayout;
import org.eclipse.swt.widgets.Display;
import org.eclipse.swt.widgets.Event;
import org.eclipse.swt.widgets.Label;
import org.eclipse.swt.widgets.Listener;
import org.eclipse.swt.widgets.Tree;
import org.eclipse.swt.widgets.TreeItem;
import org.eclipse.swt.widgets.Menu;
import org.eclipse.swt.widgets.MenuItem;
import org.eclipse.swt.widgets.MessageBox;
import org.eclipse.swt.widgets.Shell;
import org.eclipse.swt.custom.CTabFolder;
import org.eclipse.swt.custom.CTabItem;
import org.eclipse.swt.widgets.Text;
import org.eclipse.swt.widgets.ToolBar;
import org.eclipse.swt.widgets.ToolItem;

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
	void setProperties(const ref Properties p);
}

/**
 * Our main window application class
 */
class MainWindow : AdjustableComponent
{
    /**
     * Class that encapsulates the refreshing feed timers.
     */
    class RefreshTimer : Runnable
    {
        // period before each execution, in milliseconds
        int  m_period;

    public:
        /**
         * Creates a timer with a 15 minutes period.
         */
        this()
        {
            m_period = 15 * 60 * 1_000; // 15 min
        }

        /**
         * Creates a timer with a specified period.
         */
        this(int period)
        in
        {
            assert (period > 0);
        }
        body
        {
            m_period = period;
        }

        /**
         * Refresh the feeds.
         */
        override void run()
        {
            refreshAllItemsAction();
            m_shell.getDisplay().timerExec(m_period, this);
        }

        /**
         * Stop the timer
         */
        void stop()
        {
            m_shell.getDisplay().timerExec(-1, this);
        }

        /**
         * Change the period of the timer.
         */
        void setPeriod(int period)
        in
        {
            assert (period > 0);
        }
        body
        {
            stop();
            m_period = period;
        }
    }

	/// SWT window
	Shell		 m_shell;

	SashForm     m_sashForm;
	/// Feeds tree (on the left pane)
	FeedTree     m_treeFeeds;
	/// Articles table (on the right pane)
	FeedArticlesTable m_tblArticles;

    CTabFolder    m_tbfArticles;

	// Menu items
	Menu		 m_fileMenu;
	Menu         m_historyMenu;
	MenuItem     m_newFeedItem;
	MenuItem     m_newGroup;
	MenuItem     m_refreshAllFeeds;
	MenuItem	 m_exitItem;
    MenuItem     m_mnuSearch;
	MenuItem     m_removeOldArticles;
	MenuItem     m_removeHistory;
    Menu         m_helpMenu;
    MenuItem     m_about;

    // Toolbar items
    ToolBar      m_toolbar;
    ToolItem     m_tlbNewFeedItem;
    ToolItem     m_tlbNewGroup;
    ToolItem     m_tlbRefresh;
    ToolItem     m_tlbSearch;
	
	// Stores and manages the lifecycle of our GUI images.
	ResourceManager m_resMan;

    // Timer for refreshing feeds
    RefreshTimer    m_refreshTimer;

	/**
	 * Loads the images used for the GUI
	 */
	void loadImages()
	{
		m_resMan.loadImage("img/16x16/document-new.png", "newfeed");
		m_resMan.loadImage("img/16x16/folder-new.png", "newgroup");
		m_resMan.loadImage("img/rossignol.png", "appicon");
		m_resMan.loadImage("img/16x16/view-refresh.png", "refresh");
		m_resMan.loadImage("img/16x16/folder-open.png", "openFolder");
		m_resMan.loadImage("img/16x16/folder.png", "closedFolder");
		m_resMan.loadImage("img/16x16/feed.png", "feed");
        m_resMan.loadImage("img/16x16/mail-attachment.png", "attachment");
        m_resMan.loadImage("img/16x16/folder-open.png", "folderopen");
        m_resMan.loadImage("img/16x16/folder.png", "folderclosed");
        m_resMan.loadImage("img/16x16/system-search.png", "magnifier");
        m_resMan.loadImage("img/16x16/edit-find.png", "search");
		m_resMan.loadImageMap16("img/16x16/process-working.png");
	}

	/**
	 * Method responsible for creating the content of the main window menu bar.
	 */
	void createMenus()
	{
		Menu menuBar = new Menu(m_shell, SWT.BAR);
		// Create File Menu
        MenuItem cascadeFileMenu = new MenuItem(menuBar, SWT.CASCADE);
        cascadeFileMenu.setText(m_resMan.getText("FILE_MENU"));

        m_fileMenu = new Menu(m_shell, SWT.DROP_DOWN);
        cascadeFileMenu.setMenu(m_fileMenu);

		m_newFeedItem = new MenuItem(m_fileMenu, SWT.PUSH);
        m_newFeedItem.setText(m_resMan.getText("FILE_NEW_FEED"));
		m_newFeedItem.setImage(m_resMan.getImage("newfeed"));

		m_newGroup = new MenuItem(m_fileMenu, SWT.PUSH);
		m_newGroup.setText("New &group");
        m_newGroup.setText(m_resMan.getText("FILE_NEW_GROUP"));
		m_newGroup.setImage(m_resMan.getImage("newgroup"));

		new MenuItem(m_fileMenu, SWT.SEPARATOR);

		m_refreshAllFeeds = new MenuItem(m_fileMenu, SWT.PUSH);
        m_refreshAllFeeds.setText(m_resMan.getText("FILE_REFRESH_ALL_FEEDS"));
		m_refreshAllFeeds.setImage(m_resMan.getImage("refresh"));
		
		new MenuItem(m_fileMenu, SWT.SEPARATOR);

        m_exitItem= new MenuItem(m_fileMenu, SWT.PUSH);
        m_exitItem.setText(m_resMan.getText("FILE_EXIT"));
        m_shell.setMenuBar(menuBar);

		// Create edit menu
		MenuItem cascadeHistoryMenu = new MenuItem(menuBar, SWT.CASCADE);
        cascadeHistoryMenu.setText(m_resMan.getText("HISTORY_MENU"));
		m_historyMenu = new Menu(m_shell, SWT.DROP_DOWN);
		cascadeHistoryMenu.setMenu(m_historyMenu);

        m_mnuSearch = new MenuItem(m_historyMenu, SWT.PUSH);
        m_mnuSearch.setText(m_resMan.getText("HISTORY_SEARCH"));

		m_removeOldArticles = new MenuItem(m_historyMenu, SWT.PUSH);
        m_removeOldArticles.setText(m_resMan.getText("HISTORY_REMOVE_OLD_ARTICLES"));

		m_removeHistory = new MenuItem(m_historyMenu, SWT.PUSH);
        m_removeHistory.setText(m_resMan.getText("HISTORY_REMOVE_FEEDS_HISTORY"));

        // Create help menu
        MenuItem cascadeHelpMenu = new MenuItem(menuBar, SWT.CASCADE);
        cascadeHelpMenu.setText(m_resMan.getText("HELP_MENU"));
        m_helpMenu = new Menu(m_shell, SWT.DROP_DOWN);
        cascadeHelpMenu.setMenu(m_helpMenu);

        m_about = new MenuItem(m_helpMenu, SWT.PUSH);
        m_about.setText(m_resMan.getText("HELP_ABOUT"));
       


		// File menu items
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

		// edit menu items
        m_mnuSearch.addSelectionListener(
            new class SelectionAdapter
            {
                override public void widgetSelected(SelectionEvent e)
                {
                    searchAction();
                }
            });

		m_removeOldArticles.addSelectionListener(
			new class SelectionAdapter
			{
				override public void widgetSelected(SelectionEvent e)
				{
					removeOldArticlesAction();
				}
			});

		m_removeHistory.addSelectionListener(
			new class SelectionAdapter
			{
				override public void widgetSelected(SelectionEvent e)
				{
					removeHistoryAction();
				}
			});

        // Help menu item
        m_about.addSelectionListener(
            new class SelectionAdapter
            {
                override public void widgetSelected(SelectionEvent e)
                {
                    aboutAction();
                }
            });
	}

	/**
	 * Method responsible for creating the widgets inside the main window 
	 * client area.
	 */
	void createContent()
	{
		m_sashForm = new SashForm(m_shell, SWT.HORIZONTAL | SWT.SMOOTH);
		m_treeFeeds = new FeedTree(this, m_sashForm, SWT.SINGLE | SWT.H_SCROLL | SWT.V_SCROLL | SWT.BORDER);
		m_treeFeeds.loadFromFile();
        m_tbfArticles = new CTabFolder(m_sashForm, SWT.TOP | SWT.BORDER | SWT.FLAT);
        CTabItem item = new CTabItem(m_tbfArticles, SWT.NONE);
		m_tblArticles = new FeedArticlesTable(this, m_tbfArticles, SWT.SINGLE | SWT.H_SCROLL | SWT.V_SCROLL);
        item.setControl(m_tblArticles);
        item.setText(m_resMan.getText("FEED_CONTENT"));
        item.setShowClose(false);
        m_tbfArticles.setSelection(0);
		m_sashForm.setWeights([1, 4]);

        auto gridData = new GridData();
        gridData.horizontalAlignment = GridData.FILL;
        gridData.verticalAlignment = GridData.FILL;
        gridData.grabExcessHorizontalSpace = true;
        gridData.grabExcessVerticalSpace = true;
        m_sashForm.setLayoutData(gridData);

		m_shell.addListener(SWT.Close, 
			new class Listener
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

		m_treeFeeds.addSelectionListener(
			new class SelectionAdapter
			{
				override public void widgetSelected(SelectionEvent e)
				{
					auto item = cast(TreeItem)e.item;
					selectTreeItemAction(item);
				}
			});

		m_shell.addListener(SWT.Close, 
			new class Listener
			{
				override public void handleEvent(Event event)
				{
					saveProperties();
					event.doit = true;
				}
			});
	}

    /**
     * Method responsible for creating the toolbar and its buttons.
     */
    void createToolbar()
    {
        m_toolbar = new ToolBar(m_shell, SWT.FLAT | SWT.WRAP | SWT.HORIZONTAL);

        m_tlbNewFeedItem = new ToolItem(m_toolbar, SWT.PUSH);
        m_tlbNewFeedItem.setImage(m_resMan.getImage("newfeed"));
        m_tlbNewFeedItem.setToolTipText(m_resMan.getText("FILE_NEW_FEED"));
        m_tlbNewFeedItem.addSelectionListener(
            new class SelectionAdapter
            {
                override public void widgetSelected(SelectionEvent event)
                {
                    newFeedItemAction();
                }
            });

        m_tlbNewGroup = new ToolItem(m_toolbar, SWT.PUSH);
        m_tlbNewGroup.setImage(m_resMan.getImage("newgroup"));
        m_tlbNewGroup.setToolTipText(m_resMan.getText("FILE_NEW_GROUP"));
        m_tlbNewGroup.addSelectionListener(
            new class SelectionAdapter
            {
                override public void widgetSelected(SelectionEvent event)
                {
                    newFeedGroupAction();
                }
            });

        new ToolItem(m_toolbar, SWT.SEPARATOR);

        m_tlbRefresh = new ToolItem(m_toolbar, SWT.PUSH);
        m_tlbRefresh.setImage(m_resMan.getImage("refresh"));
        m_tlbRefresh.setToolTipText(m_resMan.getText("FILE_REFRESH_ALL_FEEDS"));
        m_tlbRefresh.addSelectionListener(
            new class SelectionAdapter
            {
                override public void widgetSelected(SelectionEvent event)
                {
                    refreshAllItemsAction();
                }
            });

        new ToolItem(m_toolbar, SWT.SEPARATOR);

        m_tlbSearch = new ToolItem(m_toolbar, SWT.PUSH);
        m_tlbSearch.setImage(m_resMan.getImage("search"));
        m_tlbSearch.setToolTipText(m_resMan.getText("HISTORY_SEARCH"));
        m_tlbSearch.addSelectionListener(
            new class SelectionAdapter
            {
                override public void widgetSelected(SelectionEvent event)
                {
                    searchAction();
                }
            });

        m_toolbar.pack();
    }

	/**
	 * 
	 */
	static shared(FeedInfo) getFeedInfo(string feedURL)
	{
        string xmlContent;
        if (feedURL.startsWith("https:"))
        {
            auto http = HTTP();
            http.caInfo("cert/cacert.pem");
            xmlContent = assumeUnique(cast(char[])get!(HTTP, ubyte)(feedURL, http));
        }
        else
        {
            xmlContent = assumeUnique(cast(char[])get!(AutoProtocol, ubyte)(feedURL));
        }

		auto parser = new xml.parser.Parser();
		auto handler = new FeedContentHandler(feedURL);
		parser.contentHandler = handler;

		parser.parse(xmlContent);
		return handler.getFeedInfo();
	}


	static void updateTreeItem(MainWindow self, TreeItem ti, shared(FeedInfo) fi, FeedArticlesTable table, AnimationTimer at)
	{
		// signal working in background
		self.getDisplay().syncExec(new class Runnable
					  {
						  public override void run()
						  {
                              if (!at.isRunning())
                              {
							    at.run();
                              }
						  }
					  });

		// stop the animation once this function has been terminated.
		scope (exit)
		{
            if (!self.getDisplay().isDisposed())
            {
			    self.getDisplay().asyncExec(new class Runnable
						       {
							       public override void run()
							       {
								       at.remove(ti);
                                       if (!table.isDisposed() && table.getDisplayedFeed() == fi)
								       {
									       table.refresh();
								       }
							       }
						       });
            }
		}

		auto fi2 = getFeedInfo(fi.getURL());
		size_t newArticlesCount = fi.add(fi2.getArticles());
	}

	static void removeOldFeedsInItem(MainWindow self, TreeItem ti, shared(FeedInfo) fi, time_t threshold, FeedArticlesTable table, AnimationTimer at)
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
							  if (!at.isRunning)
								  at.run();
						  }
					  });

		// stop the animation once this function has been terminated.
		scope (exit)
		{
			disp.asyncExec(new class Runnable
						   {
							   public override void run()
							   {
								   at.remove(ti);
								   if (table.getDisplayedFeed() == fi)
								   {
									   table.refresh();
								   }
							   }
						   });
		}

		fi.removeOldArticles(threshold);
	}

	static void removeHistoryInItem(MainWindow self, TreeItem ti,  shared(FeedInfo) fi, FeedTree tree, FeedArticlesTable table, AnimationTimer at)
	{
		// signal working in background
		self.getDisplay().syncExec(new class Runnable
					  {
						  public override void run()
						  {
							  if (!at.isRunning)
								  at.run();
						  }
					  });

		auto fi2 = getFeedInfo(fi.getURL());

		// stop the animation once this function has been terminated.
		self.getDisplay().asyncExec(
			new class Runnable
			{
				public override void run()
				{
					tree.setFeedInfo(ti, fi2);
					at.remove(ti);
					if (table.getDisplayedFeed() == fi)
					{
						table.setFeedInfo(fi2);
					}
				}
			});

	}

    static void searchInArticlesTitles(MainWindow self, string text, shared(FeedInfo)[] fis, CTabFolder tbfArticles)
    in
    {
        assert (self !is null);
        assert (text !is null);
        assert (fis  !is null);
        assert (tbfArticles !is null);
    }
    body
    {
        // perform the actual search
        auto results = feed.searchFeedTitles(fis, text);
        auto disp = self.getDisplay();
        disp.asyncExec(new class Runnable
                       {
                           void run()
                           {
                               auto item = new CTabItem(tbfArticles, SWT.NONE | SWT.CLOSE);
                               item.setText("\"%s\"".format(text));
                               item.setImage(self.getResourceManager().getImage("magnifier"));
                               
                               auto tblResults = new ResultsArticleTable(self, tbfArticles, SWT.SINGLE | SWT.H_SCROLL | SWT.V_SCROLL);
                               tblResults.setResults(results);
                               item.setControl(tblResults);
                               tbfArticles.setSelection(item);
                           }
                       });
    }

    /**
     * Save the GUI properties to a file.
     */
	void saveProperties()
	{
		Properties props = getProperties();
		auto settingsDir = buildPath(getSettingsDirectory(), "settings");
		if (!settingsDir.exists())
		{
			settingsDir.mkdirRecurse();
		}

		auto filename = buildPath(settingsDir, "gui.properties");
		props.writeToFile(filename);
	}

    /**
     * Handle the command line arguments that are related to the GUI.
     */
    void handleArgs(string args[])
    {
        foreach (arg; args)
        {
            if (arg.startsWith("feed://"))
            {
                newFeedItemAction(arg[7..$]);
            }
        }
    }

public:
	this(Display display, string[] args)
	{
		m_shell = new Shell(display);
		m_shell.setText("Rossignol");
        m_resMan = new ResourceManager(getDisplay());
        m_resMan.loadLanguageTexts(getUserLanguage());
        m_refreshTimer = new RefreshTimer();
		loadImages();
		createMenus();
        auto layout = new GridLayout();
        layout.numColumns = 1;
        m_shell.setLayout(layout);
        createToolbar();
		createContent();
		m_shell.setImage(m_resMan.getImage("appicon"));
        m_shell.getDisplay.timerExec(m_refreshTimer.m_period, m_refreshTimer);
	}

	void dispose()
	{
		m_shell.dispose();
		m_resMan.dispose();
	}

    /**
     * Load the GUI properties from a file
     */
	void loadProperties()
	{
		auto settingsFile = buildPath(getSettingsDirectory(), "settings",
									  "gui.properties");
		if (settingsFile.exists())
		{
			Properties props;
			props.loadFromFile(settingsFile);
			setProperties(props);
		}
	}

    /**
     * GUI action for searching 
     */
    @Action 
    void searchAction()
    {
        auto dlg = new SearchDialog(this, 0);
        string search = dlg.open();

        if (search !is null)
        {
            TreeItem[] items = m_treeFeeds.getFeedItems();
            shared(FeedInfo)[] fis = m_treeFeeds.getFeedInfo(items);

            auto searchTask = task!searchInArticlesTitles(this, search, fis, m_tbfArticles);
            searchTask.executeInNewThread();
        }
    }

    /**
     * GUI action for displaying about dialog box.
     */
    @Action 
    void aboutAction()
    {
        auto img = m_resMan.getImage("appicon");
        auto dlg = new AboutDialog(this, img, 0);
        dlg.open();
    }

	/**
	 * GUI action for adding a new feed item
	 */
	@Action
	void newFeedItemAction(string url="")
	{
		try
		{
			AddFeedDialog dlg = new AddFeedDialog(m_shell);
			auto groupNames = m_treeFeeds.getGroupNames();
			auto result = dlg.open(groupNames, url);
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
        m_treeFeeds.addGroup(m_resMan.getText("NEW_GROUP"));
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

		auto at = new AnimationTimer(this, singleArray(targetItem), m_resMan.getImageMap16());
		auto updateTask = task!updateTreeItem(this, targetItem, feedInfo, m_tblArticles, at);
		updateTask.executeInNewThread();
	}

	@Action
	void refreshAllItemsAction()
	{
		TreeItem[] items = m_treeFeeds.getFeedItems();
		shared(FeedInfo)[] fis = m_treeFeeds.getFeedInfo(items);
		auto at = new AnimationTimer(this, items, m_resMan.getImageMap16());

		foreach (i; 0..items.length)
		{
			auto updateTask = task!updateTreeItem(this, items[i], fis[i], m_tblArticles, at);
			updateTask.executeInNewThread();
		}
	}

	@Action
	void removeOldArticlesAction()
	{
		auto dlg = new RemoveOldArticlesDialog(this, 0);
		int choice = dlg.open();
		if (choice != -1)
		{
			TreeItem[] items = m_treeFeeds.getFeedItems();
			shared(FeedInfo)[] fis = m_treeFeeds.getFeedInfo(items);
			auto at = new AnimationTimer(this, items, m_resMan.getImageMap16());

			auto secsInOneDay = 60 * 60 * 24;
			time_t t_now = time(null);
			time_t threshold = t_now - (choice * secsInOneDay);

			foreach (i; 0..items.length)
			{
				auto removeTask = task!removeOldFeedsInItem(this, items[i], fis[i], threshold, m_tblArticles, at);
				removeTask.executeInNewThread();
			}
		}
	}

	@Action
	void removeHistoryAction()
	{
		TreeItem[] items = m_treeFeeds.getFeedItems();
		shared(FeedInfo)[] fis = m_treeFeeds.getFeedInfo(items);
		auto ath = new AnimationTimer(this, items, m_resMan.getImageMap16());

		foreach (i; 0..items.length)
		{
			auto removeTask = task!removeHistoryInItem(this, items[i], fis[i], m_treeFeeds, m_tblArticles, ath);
			removeTask.executeInNewThread();
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

	/** 
	 *Provides access to the GUI resources
	 */
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

		// get Sashform weights
		/*auto weights = m_sashForm.getWeights();
		props["MAINWINDOW_SASHFORM_WEIGHT_LEFT"] = to!string(weights[0]);
		props["MAINWINDOW_SASHFORM_WEIGHT_RIGHT"] = to!string(weights[1]);*/

		return props;
	}

	void setProperties(const ref Properties props)
	{
		auto wLeft = "MAINWINDOW_SASHFORM_WEIGHT_LEFT" in props;
		auto wRight = "MAINWINDOW_SASHFORM_WEIGHT_LEFT" in props;

		if (wLeft && wRight)
		{
			try
			{
				int l = to!int(*wLeft);
				int r = to!int(*wRight);
				m_sashForm.setWeights([l, r]);
			}
			catch (ConvException)
			{
			}
		}

		auto sx = "MAINWINDOW_WIDTH" in props;
		auto sy = "MAINWINDOW_HEIGHT" in props;

		if (sx && sy)
		{
			try
			{
				int x = to!int(*sx);
				int y = to!int(*sy);
				m_shell.setSize(x, y);
			}
			catch (ConvException)
			{
			}			  
		}

		m_tblArticles.setProperties(props);
	}

	alias m_shell this;
}
