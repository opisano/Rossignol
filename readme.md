# Rossignol

## What is Rossignol ?

Rossignol is a libre RSS/Atom feed client for desktop environments such as 
Microsoft Windows or GNOME. It is released under the GNU GPL3+ license and is 
written in D.

## Features

Rossignol features a hand-written, custom-made XML parser, that takes advantage 
of D features such as data immutability and slices to avoid string copying, 
improving performance and reducing memory usage. 
It uses D multithreaded facilities to provide a responsive user interface, any 
long-waiting task being performed out of the GUI thread. 
It aims at providing a simple UI that goes straight to the point.


## Dependencies

Rossignol uses libcurl for HTTP download, through the standard std.net.curl D 
module. On Linux, you'll have to make sure these libs are installed (most 
distros install them by default). On Windows, this will require you to download 
or build curl.lib, libcurl.dll and zlib1.dll from the curl and zlib websites.

* libcurl: http://curl.haxx.se/download.html
* zlib: http://zlib.net

Rossignol graphical user interface is written using DWT, the D bindings to the 
SWT toolkit. This can be found at the DWT github repository:

* https://github.com/d-widget-toolkit/dwt

## Trivia

Rossignol (pronounced ross-in-yoll) is the french for nightingale. The name was 
chosen because the first three consonant letters are RSS. I also liked the idea 
of a bird taking off to fetch the news.
