package jstoch.util;

public class Pair<T>
{
	public T first;
	public T second;
	private transient final int hash;
	
	public Pair(T first, T second)
	{
		this.first = first;
		this.second = second;
		hash = (first == null ? 0 : first.hashCode() * 31) + (second == null ? 0 : second.hashCode());
	}
	
	@Override
	public int hashCode()
	{
		return hash;
	}
	
	@SuppressWarnings("unchecked")
	@Override
	public boolean equals(Object obj)
	{
		if(this == obj) return true;
		if(obj == null || !getClass().isInstance(obj)) return false;
		
		Pair<T> pair = getClass().cast(obj);
		
		return (first == null ? pair.first == null : first.equals(pair.first))
		&& (second == null ? pair.second == null : second.equals(pair.second));
	}
	
	@Override
	public String toString()
	{
		return String.format("(%s, %s)", first, second);
	}
}
