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

module resources;

import std.exception;
import std.file;
import std.path;

import org.eclipse.swt.graphics.GC;
import org.eclipse.swt.graphics.Image;
import org.eclipse.swt.widgets.Display;

import properties;

class ResourceManager
{
private:
	Display m_disp;
    // Holds interface images
	Image[string] m_images;
    // Holds interface waiting animation
	Image[]       m_imageMap16;
    // Holds interface texts
    Properties    m_texts;

public:
	this(Display disp)
	{
		m_disp = disp;
	}

	void init(Display disp)
	{
		m_disp = disp;
	}

	void dispose()
	{
		foreach (image; m_images.byValue())
		{
			image.dispose();
		}
		m_images = m_images.init;

		if (m_imageMap16)
		{
			foreach(image; m_imageMap16)
			{
				image.dispose();
			}
		}
	}

	/**
	 * Loads an image and stores it in this 
	 * ResourceManager under a certain key.
	 */
	void loadImage(string filename, string key)
	in
	{
		assert (filename !is null);
		assert (key !is null);
	}
	body
	{
		// dispose any image already stored under this key.
		auto previous = (key in m_images);
		if (previous)
		{
			(*previous).dispose();
		}

		// load image and store it in the map
		auto img = new Image(m_disp, filename);
		m_images[key] = img;
	}

	/**
	 * Load the 16x16 waiting animation.
	 */
	void loadImageMap16(string filename)
	in
	{
		assert (filename !is null);
		assert (m_imageMap16 is null);
	}
	body
	{
		// Load the 128x64 source image 
		auto imageMap = new Image(m_disp, filename);
		scope (exit)
		{
			imageMap.dispose();
		}

		// Create the image array
		m_imageMap16 = new Image[32];
		foreach (index; 0..32)
		{
			// create a small 16x16 image
			m_imageMap16[index] = new Image(m_disp, 16, 16);
			int origX = (index % 8) * 16;
			int origY = (index / 8) * 16;

			// copy source image portion into the small image
			GC gc = new GC(m_imageMap16[index]);
			scope (exit)
			{
				gc.dispose();
			}
			gc.drawImage(imageMap, 
						 origX, origY, 
						 16, 16, 
						 0, 0, 
						 16, 16);
		}
	}

	/**
	 * Gets the image associated with a key.
	 */
	Image getImage(string key)
	in
	{
		assert (key in m_images);
	}
	out (img)
	{
		assert (img !is null);
	}
	body
	{
		return m_images[key];
	}

	Image[] getImageMap16()
	{
		return m_imageMap16;
	}

    /**
     * Load language texts.
     */
    void loadLanguageTexts(string locale)
    {
        auto langFile = buildPath("lang", locale ~ ".properties");

        if (locale is null || !langFile.exists())
        {
            langFile = buildPath("lang", "en-US.properties");
        }

        enforce(langFile.exists());

        m_texts.loadFromFile(langFile);
    }
}