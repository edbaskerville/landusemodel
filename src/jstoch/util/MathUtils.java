package jstoch.util;

import static java.lang.Math.*;

import java.io.*;

import java.util.*;

public class MathUtils
{
	private static double log2 = Math.log(2);
	
	public static double log2(double value)
	{
		return log(value)/log2;
	}
	
	public static int log2Scale(double value)
	{
		return (int)floor(log2(value));
	}
	
	public static int[] readIntArray(InputStream stream) throws IOException
	{
		List<Integer> listRep = new ArrayList<Integer>();
		
		BufferedReader reader = new BufferedReader(new InputStreamReader(stream));
		while(reader.ready())
		{
			String line = reader.readLine();
			String[] vals = line.trim().split("\\s+");
			for(String val : vals)
			{
				listRep.add(Integer.parseInt(val));
			}
		}
		reader.close();
		
		int size = listRep.size();
		int[] arrayRep = new int[size];
		
		for(int i = 0; i < size; i++)
		{
			arrayRep[i] = listRep.get(i);
		}
		
		return arrayRep;
	}
	
	public static double[] readDoubleArray(InputStream stream) throws IOException
	{
		List<Double> listRep = new ArrayList<Double>();
		
		BufferedReader reader = new BufferedReader(new InputStreamReader(stream));
		while(reader.ready())
		{
			String line = reader.readLine();
			String[] vals = line.trim().split("\\s+");
			for(String val : vals)
			{
				listRep.add(Double.parseDouble(val));
			}
		}
		reader.close();
		
		int size = listRep.size();
		double[] arrayRep = new double[size];
		
		for(int i = 0; i < size; i++)
		{
			arrayRep[i] = listRep.get(i);
		}
		
		return arrayRep;
	}
	
	public static int[][] readIntMatrix(InputStream stream) throws IOException
	{
		List<List<Integer>> listRep = new ArrayList<List<Integer>>();
		
		BufferedReader reader = new BufferedReader(new InputStreamReader(stream));
		while(reader.ready())
		{
			String line = reader.readLine();
			String[] vals = line.trim().split("\\s+");
			
			List<Integer> row = new ArrayList<Integer>();
			for(String val : vals)
			{
				row.add(Integer.parseInt(val));
			}
			listRep.add(row);
		}
		reader.close();
		
		int rows = listRep.size();
		int[][] arrayRep = new int[listRep.size()][];
		for(int i = 0; i < rows; i++)
		{
			List<Integer> row = listRep.get(i);
			int cols = row.size();
			arrayRep[i] = new int[cols];
			for(int j = 0; j < cols; j++)
			{
				arrayRep[i][j] = row.get(j);
			}
		}
		
		return arrayRep;
	}
	
	public static double[][] readDoubleMatrix(InputStream stream) throws IOException
	{
		List<List<Double>> listRep = new ArrayList<List<Double>>();
		
		BufferedReader reader = new BufferedReader(new InputStreamReader(stream));
		while(reader.ready())
		{
			String line = reader.readLine();
			String[] vals = line.trim().split("\\s+");
			
			List<Double> row = new ArrayList<Double>();
			for(String val : vals)
			{
				row.add(Double.parseDouble(val));
			}
			listRep.add(row);
		}
		reader.close();
		
		int rows = listRep.size();
		double[][] arrayRep = new double[listRep.size()][];
		for(int i = 0; i < rows; i++)
		{
			List<Double> row = listRep.get(i);
			int cols = row.size();
			arrayRep[i] = new double[cols];
			for(int j = 0; j < cols; j++)
			{
				arrayRep[i][j] = row.get(j);
			}
		}
		
		return arrayRep;
	}
}
