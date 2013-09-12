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

module gui.dialogs;

import std.conv;
import std.datetime;

import org.eclipse.swt.SWT;
import org.eclipse.swt.events.SelectionAdapter;
import org.eclipse.swt.events.SelectionEvent;
import org.eclipse.swt.graphics.Image;
import org.eclipse.swt.layout.GridData;
import org.eclipse.swt.layout.GridLayout;
import org.eclipse.swt.widgets.Button;
import org.eclipse.swt.widgets.Combo;
import org.eclipse.swt.widgets.Dialog;
import org.eclipse.swt.widgets.Label;
import org.eclipse.swt.widgets.Shell;
import org.eclipse.swt.widgets.Spinner;
import org.eclipse.swt.widgets.Text;

import gui.mainwindow;

/**
 * The type returned by the add feed dialog
 */
struct AddFeedResult
{
    /// URL of the feed.
	string url;
    /// Group to put the feed in. 
	string group;
}

/**
 * The dialog box the user has to fill in order to add a new 
 * feed.
 */
final class AddFeedDialog : Dialog
{
	AddFeedResult m_result;
	Shell  m_dialog;
	Text   m_txtUrl;
	Combo  m_cmbGroups;

	Button m_btnOk;
	Button m_btnCancel;

public:
	this(Shell parent, int style)
	{
		super(parent, style);
	}

	this(Shell parent)
	{
		this(parent, 0);
	}
	
	AddFeedResult open(R)(R groupNames, string url="")
	{
		auto parent = getParent();

        // Create a modal dialog
		m_dialog    = new Shell(parent, SWT.PRIMARY_MODAL | SWT.DIALOG_TRIM | SWT.DOUBLE_BUFFERED );
		m_dialog.setBackgroundMode(SWT.INHERIT_FORCE);
		m_dialog.setLayout(new GridLayout(2, false));
		m_dialog.setText("Add new feed...");

        // Feed URL
		Label lblUrl = new Label(m_dialog, SWT.NONE);
		lblUrl.setText("Feed location: ");
		lblUrl.setBackground(m_dialog.getBackground());

		m_txtUrl    = new Text(m_dialog, SWT.SINGLE | SWT.BORDER);
		GridData gridData = new GridData();
		gridData.widthHint = 200;
		gridData.horizontalAlignment = SWT.FILL;
		gridData.grabExcessHorizontalSpace = true;
		m_txtUrl.setLayoutData(gridData);
        m_txtUrl.setText(url);

        // Group combo
		Label lblGroups = new Label(m_dialog, SWT.NONE);
		lblGroups.setText("Add to group: ");
		lblGroups.setBackground(m_dialog.getBackground());

		m_cmbGroups = new Combo(m_dialog, SWT.DROP_DOWN | SWT.READ_ONLY | SWT.BORDER);
		foreach (groupName; groupNames)
		{
			m_cmbGroups.add(groupName);
		}
		m_cmbGroups.select(0);

        // OK/Cancel buttons.
		m_btnOk     = new Button(m_dialog, SWT.PUSH);
		m_btnOk.setText("OK");
		m_btnOk.setBackground(m_dialog.getBackground());
		m_btnOk.addSelectionListener(
            new class SelectionAdapter
			{
                // On click on OK button
				override void widgetSelected(SelectionEvent e)
				{
					m_result.url = m_txtUrl.getText();
					m_result.group = m_cmbGroups.getText();
					m_dialog.dispose();
				} 
			});

		m_btnCancel = new Button(m_dialog, SWT.PUSH);
		m_btnCancel.setText("Cancel");
		m_btnCancel.setBackground(m_dialog.getBackground());
		m_btnCancel.addSelectionListener(
            new class SelectionAdapter
			{
                // On click on Cancel button
				override void widgetSelected(SelectionEvent e)
				{
					m_result = m_result.init;
					m_dialog.dispose();
				} 
			});

		m_dialog.pack();
		m_dialog.open();

        // Dialog message loop
		auto display = parent.getDisplay();
		while (!m_dialog.isDisposed())
		{
			if (!display.readAndDispatch())
			{
				display.sleep();
			}
		}
		return m_result;
	}
}

/**
 * About dialog
 */
final class AboutDialog : Dialog
{
	Shell m_dialog;
    Image m_image;
    enum license = import("license.txt");

public:
	this(Shell parent, Image image, int style)
	{
		super(parent, style);
        m_image = image;
	}

	void open()
	{
        auto parent = getParent();

        // create dialog window
		m_dialog    = new Shell(parent, SWT.PRIMARY_MODAL | SWT.DIALOG_TRIM | SWT.DOUBLE_BUFFERED );
        m_dialog.setBackgroundMode(SWT.INHERIT_FORCE);
		m_dialog.setLayout(new GridLayout(2, false));
		m_dialog.setText("About Rossignol");
        m_dialog.setSize(512, 384);

        auto lblImage = new Label(m_dialog, 0);
        lblImage.setImage(m_image);
        
        auto lblPrompt = new Label(m_dialog, 0);
        lblPrompt.setText("Rossignol version 0.3");

        auto txtLicense = new Text(m_dialog, SWT.BORDER | SWT.MULTI  | SWT.V_SCROLL | SWT.H_SCROLL);
        auto gridData = new GridData(GridData.FILL_BOTH);
        gridData.horizontalSpan = 2;
        

        txtLicense.setLayoutData(gridData);
        txtLicense.setText(license);
        txtLicense.setEditable(false);
		m_dialog.open();

        // Dialog message loop
		auto display = parent.getDisplay();
		while (!m_dialog.isDisposed())
		{
			if (!display.readAndDispatch())
			{
				display.sleep();
			}
		}
	}
}


final class RemoveOldArticlesDialog : Dialog
{
	MainWindow m_mainWindow;
	Shell m_dialog;
	int m_result;

public:
	this(MainWindow mainWindow)
	{
		this(mainWindow, 0);
	}

	this(MainWindow mainWindow, int style)
	{
		super(mainWindow.m_shell, style);
		m_mainWindow = mainWindow;
	}

	/**
	 * Returns the duration chosen by the user in days, or -1 
	 * if the user did cancel.
	 */
	int open()
	{
		m_result = -1;
		m_dialog    = new Shell(m_mainWindow.m_shell, SWT.PRIMARY_MODAL | SWT.DIALOG_TRIM | SWT.DOUBLE_BUFFERED );
		m_dialog.setBackgroundMode(SWT.INHERIT_FORCE);

		auto gl = new GridLayout(2, false);
		gl.marginWidth = 10;
		m_dialog.setLayout(gl);
		
		m_dialog.setText("Remove old articles...");

		auto lblPrompt = new Label(m_dialog, SWT.NONE);
		lblPrompt.setText("Remove articles older than:");
		GridData gridData = new GridData();
		gridData.horizontalAlignment = GridData.FILL;
		gridData.horizontalSpan = 2;
		lblPrompt.setLayoutData(gridData);

		auto spnQty = new Spinner(m_dialog, SWT.BORDER);
		spnQty.setMinimum(1);
		spnQty.setSelection(30);
		auto cmbUnit = new Combo(m_dialog, SWT.DROP_DOWN | SWT.READ_ONLY | SWT.BORDER);
		cmbUnit.add("day(s)");
		cmbUnit.add("month(s)");
		cmbUnit.add("year(s)");
		cmbUnit.select(0);


		auto btnOk = new Button(m_dialog, SWT.PUSH);
		btnOk.setText("OK");
		btnOk.setBackground(m_dialog.getBackground());
		btnOk.addSelectionListener(
			new class SelectionAdapter
			{
				override void widgetSelected(SelectionEvent e)
				{
					int multiplicator;
					switch (cmbUnit.getSelectionIndex())
					{
						case 0:	// days
							multiplicator = 1;
							break;
						case 1: // months
							multiplicator = 30;
							break;
						case 2: // years
							multiplicator = 365;
							break;
						default:
							assert(0);	   
					}
					m_result = to!int(spnQty.getText()) * multiplicator;
					m_dialog.dispose();
				} 
			});

		auto btnCancel = new Button(m_dialog, SWT.PUSH);
		btnCancel.setText("Cancel");
		btnCancel.setBackground(m_dialog.getBackground());
		btnCancel.addSelectionListener(
			new class SelectionAdapter
			{
				override void widgetSelected(SelectionEvent e)
				{
					m_result = -1;
					m_dialog.dispose();
				}
			});

		m_dialog.pack();
		m_dialog.open();

		auto display = getParent().getDisplay();
		while (!m_dialog.isDisposed())
		{
			if (!display.readAndDispatch())
			{
				display.sleep();
			}
		}
		return m_result;

	}
}