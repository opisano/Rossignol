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

module log;

import std.datetime;
import std.string;

/**
 * Levels of logging
 */
enum LogLevel
{
    info,
    warning,
    error,
    fatal
}

/**
 * Provides a string representation of a LogLevel value.
 *
 * Example: toString(LogLevel.warning) returns "warning".
 */
string toString(LogLevel lvl) pure nothrow
{
    final switch (lvl)
    {
    case LogLevel.info:
        return "info";
    case LogLevel.warning:
        return "warning";
    case LogLevel.error:
        return "error";
    case LogLevel.fatal:
        return "fatal";
    }
}

/** 
 * Provides a way of testing if a type implements the LoggingProvider concept.
 * LoggingProviders must implement a doLog(string) method.
 *
 */
template isLoggingProvider(T)
{
    enum bool isLoggingProvider = is(
        typeof(
            (inout int = 0)
            {
                T t = void;
                t.doLog("message"); // Must provide a doLog method
            }));
}


/**
 * This class provides general logging interface. 
 * It does not perform the logging itself, but delegates it 
 * to a instance of the type passed in template parameter, for 
 * maximum flexibility.
 *
 * params:
 * - LogProvider: The type to use to perform the actual logging. this must 
 *              be a class that implements the LoggingProvider concept.
 */
final class Logger(LoggingProvider) 
        if (isLoggingProvider!LoggingProvider)
{
    LoggingProvider m_impl;
    LogLevel  m_lvl;

public:

    /**
     * Create a Logger instance, forwarding any arguments to the LoggerImpl
     * used internally.
     */
    this(T...)(T args)
    {
        m_impl = new LoggingProvider(args);
    }

    /** 
     * Returns the current log level (any message with log level lower than 
     * this will be discarded).
     */
    @property LogLevel logLevel() const pure nothrow
    {
        return m_lvl;
    }

    /** 
     * Sets the current log level (any message with log level lower than 
     * this will be discarded).
     */
    @property void logLevel(LogLevel lvl) pure nothrow
    {
        m_lvl = lvl;
    }

    /**
     * This methods checks if the message passed in parameter 
     * must be logged or not and formats and forwards it to the LogProvider if it is 
     * the case.
     */
    void log(lazy string message, LogLevel lvl = LogLevel.info)
    {
        if (lvl >= m_lvl)
        {
            auto msgLogged = "%s - [%s]\t%s".format(Clock.currTime().toISOString(), lvl.toString(), message);
            m_impl.doLog(message);
        }
    }

    /** Forward invocation of any other method to the LoggingProvider */
    alias m_impl this;
}

/** 
 * Logs message in memory and provides a Range interface to access them.
 */
class MemoryLog
{
    string[] m_log;

    struct Range
    {
        string[] m_data;

        this(string[] data)
        {
            m_data = data;
        }
        
        @property string front()
        {
            return m_data[0];
        }

        void popFront()
        {
            m_data = m_data[1..$];
        }

        @property bool empty()
        {
            return m_data.length == 0;
        }

        Range save()
        {
            return this;
        }

        @property string back()
        {
            return m_data[$-1];
        }

        void popBack()
        {
            m_data = m_data[0..$-1];
        }

        string opIndex(size_t index)
        {
            return m_data[index];
        }

        @property size_t length() const
        {
            return m_data.length;
        }
    }
public:
    void doLog(string s)
    {
        m_log ~= s;
    }

    auto range() 
    {
        return Range(m_log);
    }
}

unittest
{
    auto logger = new Logger!MemoryLog();
    logger.log("First log", LogLevel.info);
    logger.log("Sencond log", LogLevel.warning);
    logger.log("Third log", LogLevel.error);

    string s;
    foreach (message; logger.range())
    {
        s = message;
    }
}