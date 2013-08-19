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

import std.datetime;

import org.eclipse.swt.SWT;
import org.eclipse.swt.events.SelectionAdapter;
import org.eclipse.swt.events.SelectionEvent;
import org.eclipse.swt.layout.GridData;
import org.eclipse.swt.layout.GridLayout;
import org.eclipse.swt.widgets.Button;
import org.eclipse.swt.widgets.Combo;
import org.eclipse.swt.widgets.Dialog;
import org.eclipse.swt.widgets.Label;
import org.eclipse.swt.widgets.Shell;
import org.eclipse.swt.widgets.Text;

import gui.mainwindow;

struct AddFeedResult
{
	string url;
	string group;
}

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
	
	AddFeedResult open(R)(R groupNames)
	{
		auto parent = getParent();

		m_dialog    = new Shell(parent, SWT.PRIMARY_MODAL | SWT.DIALOG_TRIM | SWT.DOUBLE_BUFFERED );
		m_dialog.setBackgroundMode(SWT.INHERIT_FORCE);
		m_dialog.setLayout(new GridLayout(2, false));
		m_dialog.setText("Add new feed...");

		Label lblUrl = new Label(m_dialog, SWT.NONE);
		lblUrl.setText("Feed location: ");
		lblUrl.setBackground(m_dialog.getBackground());

		m_txtUrl    = new Text(m_dialog, SWT.SINGLE | SWT.BORDER);
		GridData gridData = new GridData();
		gridData.widthHint = 200;
		gridData.horizontalAlignment = SWT.FILL;
		gridData.grabExcessHorizontalSpace = true;
		m_txtUrl.setLayoutData(gridData);

		Label lblGroups = new Label(m_dialog, SWT.NONE);
		lblGroups.setText("Add to group: ");
		lblGroups.setBackground(m_dialog.getBackground());

		m_cmbGroups = new Combo(m_dialog, SWT.DROP_DOWN | SWT.READ_ONLY | SWT.BORDER);
		foreach (groupName; groupNames)
		{
			m_cmbGroups.add(groupName);
		}
		m_cmbGroups.select(0);

		m_btnOk     = new Button(m_dialog, SWT.PUSH);
		m_btnOk.setText("OK");
		m_btnOk.setBackground(m_dialog.getBackground());
		m_btnOk.addSelectionListener(new class SelectionAdapter
			{
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
		m_btnCancel.addSelectionListener(new class SelectionAdapter
			{
				override void widgetSelected(SelectionEvent e)
				{
					m_result = m_result.init;
					m_dialog.dispose();
				} 
			});

		m_dialog.pack();
		m_dialog.open();

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

final class AboutDialog : Dialog
{
	Shell m_dialog;
public:
	this(MainWindow parent, int style)
	{
		super(parent.m_shell, style);
	}

	void open()
	{
		Label lbl;
	}
}