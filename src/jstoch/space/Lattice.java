package jstoch.space;

import java.util.*;

import cern.jet.random.Uniform;
import cern.jet.random.engine.RandomEngine;

public class Lattice<T> implements Space<T>
{
	public enum BoundaryCondition
	{
		Bounded,
		Periodic
	}
	
	public enum NeighborhoodType
	{
		Moore(new int[][] {{1, 1}, {1, 0}, {1, -1}, {0, -1}, {-1, -1}, {-1, 0}, {-1, 1}} ),
		VonNeumann(new int[][] {{0, 1}, {1, 0}, {0, -1}, {-1, 0}});
		
		private final int[][] neighborOffsets;
		
		NeighborhoodType(int[][] neighborOffsets)
		{
			this.neighborOffsets = neighborOffsets;
		}
		
		public int[][] neighborOffsets()
		{
			return neighborOffsets;
		}
		
		public int size()
		{
			return neighborOffsets.length;
		}
	}
	
	int numRows, numCols;
	protected Object[][] sites;
	
	private BoundaryCondition boundaryCondition;
	private NeighborhoodType neighborhoodType;
	
	public Lattice(int rows, int cols, BoundaryCondition boundaryCondition)
	{
		this(rows, cols, boundaryCondition, NeighborhoodType.VonNeumann);
	}
	
	public Lattice(int numRows, int numCols, BoundaryCondition boundaryCondition,
			NeighborhoodType neighborhoodType)
	{
		this.numRows = numRows;
		this.numCols = numCols;
		sites = new Object[numRows][numCols];
		this.boundaryCondition = boundaryCondition;
		this.neighborhoodType = neighborhoodType; 
	}
	
	public void put(T obj, int row, int col)
	{
		if(row < numRows && row >= 0 && col < numCols && col >= 0)
		{
			sites[row][col] = obj;
		}
		else
		{
			throw new IllegalArgumentException("Invalid cell " + row + ", " + col + ".");
		}
	}
	
	public List<T> getNeighbors(int row, int col)
	{
		List<T> neighborList = new ArrayList<T>(neighborhoodType.size());
		for(int[] neighborOffset : neighborhoodType.neighborOffsets())
		{
			neighborList.add(get(row + neighborOffset[0], col + neighborOffset[1]));
		}
		return neighborList;
	}
	
	@SuppressWarnings("unchecked")
	public T get(int row, int col)
	{
		if(row >= 0 && row < numRows && col >= 0 && col < numCols)
		{
			return (T)sites[row][col];
		}
		
		switch(boundaryCondition)
		{
			case Periodic:
				return (T)sites[posMod(row, numRows)][posMod(col, numCols)];
			default:
				return null;
		}
	}
	
	public int getNumRows()
	{
		return numRows;
	}
	
	public int getNumCols()
	{
		return numCols;
	}
	
	public NeighborhoodType getNeighborhoodType()
	{
		return neighborhoodType;
	}
	
	public BoundaryCondition getBoundaryCondition()
	{
		return boundaryCondition;
	}
	
	private static int posMod(int val, int base)
	{
		int mod = val % base;
		while(mod < 0)
		{
			val += base;
			mod = val % base;
		}
		return mod;
	}

	@SuppressWarnings("unchecked")
	public void initializeRandom(RandomEngine rng, Set<T> set)
	{
		Uniform uniform = new Uniform(rng);
		Object[] array = set.toArray();
		
		for(int row = 0; row < numRows; row++)
		{
			for(int col = 0; col < numCols; col++)
			{
				put((T)array[uniform.nextIntFromTo(0, array.length - 1)], row, col);
			}
		}
	}
}
