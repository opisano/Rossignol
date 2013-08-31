# Path to the DWT directory
DWTDIR=../dwt
CURLDIR=../curl/lib/.libs
LIBDIR=/usr/lib/i386-linux-gnu
#D compiler
DC=dmd
# Compiler flags
DFLAGS=-m32 -c -I$(DWTDIR)/imp -J$(DWTDIR)/org.eclipse.swt.gtk.linux.x86/res -J.
DDEBUG=-g -debug -unittest
DRELEASE=-O -release -inline
# Linker flags
LFLAGS=-lgtk-x11-2.0 -lgdk-x11-2.0 -latk-1.0 -lgio-2.0 -lpangoft2-1.0 -lpangocairo-1.0 -lgdk_pixbuf-2.0 -lcairo -lpango-1.0 -lfreetype -lfontconfig -lgobject-2.0 -lglib-2.0 -lXtst -lgthread-2.0 -lgnomeui-2
TARGET=rossignol

SOURCES=date.d feed.d linux.d main.d properties.d resources.d system.d text.d \
windows.d gui/animation.d gui/articletable.d gui/dialogs.d gui/feedtree.d \
gui/mainwindow.d html/html.d xml/attributes.d xml/encoding.d xml/entities.d \
xml/except.d xml/handler.d xml/parser.d 

OBJS=$(patsubst %d,%o,$(SOURCES))

%.o: %.d
	$(DC) $(DFLAGS) $(DRELEASE) -of$@ $^

all: $(OBJS)
	gcc -m32 -o $(TARGET)  $^ $(DWTDIR)/lib/org.eclipse.swt.gtk.linux.x86.a $(DWTDIR)/lib/dwt-base.a $(LIBDIR)/libphobos2.a -lcurl $(LFLAGS) -pthread -Wl,-export-dynamic
	
	
clean:
	rm -f *.o
	rm -f *~
	rm -f gui/*.o
	rm -f gui/*~
	rm -f html/*.o
	rm -f html/*~
	rm -f xml/*.o
	rm -f xml/*~
