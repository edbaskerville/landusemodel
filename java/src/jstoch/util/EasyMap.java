package jstoch.util;

import java.util.HashMap;
import java.util.Map;

public class EasyMap<K, V> extends HashMap<K, V>
{
	private static final long serialVersionUID = 1L;

	@SuppressWarnings("unchecked")
	public EasyMap(Object...keysAndValues)
	{
		super(keysAndValues.length / 2);
		
		if(keysAndValues.length % 2  == 1)
			throw new IllegalArgumentException("Need an even number of arguments to create map from key/value pairs.");
		
		int numPairs = keysAndValues.length / 2;
		for(int i = 0; i < numPairs; i++)
		{
			put((K)keysAndValues[i*2], (V)keysAndValues[i*2 + 1]);
		}
	}
	
	public EasyMap()
	{
	}
	
	public EasyMap(int initialCapacity)
	{
		super(initialCapacity);
	}
	
	public EasyMap(Map<? extends K, ? extends V> m)
	{
		super(m);
	}
	
	public EasyMap(int initialCapacity, float loadFactor)
	{
		super(initialCapacity, loadFactor);
	}
	
}
