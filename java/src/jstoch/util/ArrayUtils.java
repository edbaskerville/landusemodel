package jstoch.util;

public class ArrayUtils
{
	public static <T> String arrayToLongString(T[] array)
	{
		StringBuilder sb = new StringBuilder();
		
		sb.append("[");
		for(int i = 0; i < array.length; i++)
		{
			sb.append(array[i].toString());
			if(i != array.length - 1) sb.append(", ");
		}
		sb.append("]");
		
		return sb.toString();
	}
	
	public static String arrayToLongString(int[] array)
	{
		StringBuilder sb = new StringBuilder();
		
		sb.append("[");
		for(int i = 0; i < array.length; i++)
		{
			sb.append(array[i]);
			if(i != array.length - 1) sb.append(", ");
		}
		sb.append("]");
		
		return sb.toString();
	}
}
