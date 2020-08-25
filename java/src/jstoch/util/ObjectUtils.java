package jstoch.util;

import java.lang.reflect.*;

public class ObjectUtils
{
	public static Object newInstance(String className, Object... args) throws Exception
	{
		return newInstance(Class.forName(className), args);
	}
	
	public static Object newInstance(Class<?> tClass, Object... args) throws Exception
	{
		Exception lastException = null;
		for(Constructor<?> constructor : tClass.getConstructors())
		{
			try
			{
				return constructor.newInstance(args);
			}
			catch (Exception e)
			{
				lastException = e;
			}
		}
		throw lastException;
	}
}
