package jstoch.util;

import java.util.*;

@SuppressWarnings("serial")
public class EasyList<E> extends ArrayList<E>
{
	public EasyList(E...objs)
	{
		super(objs.length);
		for(E obj : objs)
		{
			add(obj);
		}
	}
	
	public EasyList()
	{
		super();
	}

	public EasyList(Collection<? extends E> c)
	{
		super(c);
	}

	public EasyList(int initialCapacity)
	{
		super(initialCapacity);
	}

}
