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

module main;

import core.thread;

import std.array;
import std.conv;
import std.file;
import std.path;
import std.stdio;
import std.string;

import java.lang.Runnable;

import org.eclipse.swt.graphics.Point;
import org.eclipse.swt.graphics.Rectangle;
import org.eclipse.swt.widgets.Display;
import org.eclipse.swt.widgets.Shell;

import feed;
import gui.mainwindow;
import system;


version (Windows)
{
    import windows;
    enum TOKEN_NAME = "Global\\RossignolMutex";
    enum SERVER_ADDRESS = r"\\.\pipe\RossignolPipe";
}
version (linux)
{
    import linux;
    enum SERVER_ADDRESS = "/tmp/socket-rossignol";
    string TOKEN_NAME;
}

/**
 * Creates a server thread from which this process listens to 
 * messages coming from other Rossignol processes.
 */
class IPCServerThread : Thread
{
    MainWindow m_mainWindow;
    Display    m_display;

    void run()
    {
        // Create a server pipe
        auto ipc = IPC.createServer(SERVER_ADDRESS);

        while (1)
        {
            // wait for data from other process
            string s = ipc.read();
            string[] lines = s.splitLines();
            foreach (line; lines)
            {
                if (line.startsWith("feed://"))
                {
                    m_display.asyncExec(
                        new class Runnable
                        {
                            override void run()
                            {
                                try
                                {
                                    if (!m_mainWindow.isDisposed())
                                    {
                                        m_mainWindow.newFeedItemAction(line[7..$]);
                                    }
                                }
                                catch (Exception) 
                                {
                                }
                            }
                        });
                }
            }
        }
    }

public:
    this(MainWindow mainWindow, Display display)
    {
        super(&run);
        m_mainWindow = mainWindow;
        m_display    = display;
    }
}


/**
 * Modelizes our application
 */
class Application
{

public: 
	this(Display display, string[] args)
	{
		// create our main window
		MainWindow win = new MainWindow(display, args);
		win.loadProperties();
		win.open();
        win.handleArgs(args);

        // create IPC server
        auto thread = new IPCServerThread(win, display);
        thread.name = "IPC Server";
        thread.isDaemon = true;
        thread.start();

		while (!win.isDisposed())
		{
			if (!display.readAndDispatch())
				display.sleep();
		}
		win.dispose();
	}

	static void setCurrentDir()
	{
		string path = system.getApplicationPath();
		chdir(path);
	}
}

int main(string[] argv)
{
    version (linux)
    {
        TOKEN_NAME = getTokenName();
    }
    
    // Named mutex used to detect if another instance of this application 
    // is already running.
    Token mutex = Token.create(TOKEN_NAME);
    if (mutex.owned) // No other instance is running
    {
	    Application.setCurrentDir();	
	    Display display = new Display();
	    new Application(display, argv);
	    display.dispose();
    }
    else
    {
        // If we have arguments to send to the other process
        if (argv.length > 1)
        {
            // Connect to the other process and send args
            auto pipe = IPC.createClient(SERVER_ADDRESS);
            auto args = argv[1..$].join("\n");
            if (args.length < 2_048)
            {
                pipe.write(args);
            }
        }
    }
	
	return 0;
}
