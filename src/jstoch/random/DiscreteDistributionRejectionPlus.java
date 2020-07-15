/**
 * 
 */
package jstoch.random;

import java.util.*;
import cern.jet.random.engine.RandomEngine;

/**
 * Represents a discrete probability distribution that changes in time.
 * Implemented using a modified rejection method where the lookup
 * table is constructed using proportionally more bins for larger weights.
 * @author Ed Baskerville
 *
 */
public class DiscreteDistributionRejectionPlus<T> extends DiscreteDistributionAbstract<T>
{
	private int drawCount;
	private int rejectionCount;
	private int nullCount;
	
	private int drawCountSinceDefrag;
	private int rejectionCountSinceDefrag;
	private int nullCountSinceDefrag;
	
	/**
	 * Underlying random number generator.
	 */
	RandomEngine rng;
	
	/**
	 * Weight assigned to each location in lookup table.
	 */
	private double binWeight;
	
	/**
	 * Lookup table: stores values corresponding to this location.
	 */
	private List<T> lookupTable;
	
	/**
	 * Map between values and weights.
	 */
	private Map<T, Double> weightMap;
	
	private double totalWeight;
	
	/**
	 * Queue of free locations in lookup table.
	 */
	private List<Integer> freeQueue;
	
	/**
	 * Map between values and locations in lookup table.
	 */
	private Map<T, Set<Integer>> locationMap;
	
	/**
	 * Constructor
	 */
	public DiscreteDistributionRejectionPlus(double binWeight, RandomEngine rng)
	{
		this(binWeight, new HashMap<T, Double>(), rng);
	}
	
	public DiscreteDistributionRejectionPlus(double binWeight, HashMap<T, Double> weights, RandomEngine rng)
	{
		this.binWeight = binWeight;
		this.rng = rng;

		weightMap = weights;
		totalWeight = 0;
		
		lookupTable = new ArrayList<T>(weightMap.size());
		freeQueue = new LinkedList<Integer>();
		locationMap = new HashMap<T, Set<Integer>>(weightMap.size());
		
		for(T value : weights.keySet())
		{
			double weight = weights.get(value);
			update(value, weight, false);
			totalWeight += weight;
		}
	}
	
	public int getSize()
	{
		return weightMap.size();
	}

	public double getWeight(T value)
	{
		if(!weightMap.containsKey(value)) return 0;
		return weightMap.get(value);
	}

	public T nextValue()
	{
		if(weightMap.size() == 0) return null;
		
		// Rejection method adjusted for number of bins
		// assigned to the selected object. The acceptance rate
		// is equal to weight / (# bins * weight of each bin)
		// (Why can't we call it the "acceptance" method?)
		boolean accepted = false;
		T value = null;
		while(!accepted)
		{
			int index = Math.abs(rng.nextInt() % lookupTable.size());
			value = lookupTable.get(index);
			if(value != null)
			{
				int numBins = locationMap.get(value).size();
				double acceptanceRate = weightMap.get(value) / (numBins * binWeight);
				if(rng.nextDouble() < acceptanceRate)
				{
					accepted = true;
				}
				else
				{
					rejectionCountSinceDefrag++;
				}
			}
			else
			{
				nullCountSinceDefrag++;
			}
			drawCountSinceDefrag++;
		}
		
		// Complete empirical guess
		if((double)nullCountSinceDefrag / drawCountSinceDefrag > 0.3)
		{
			defragment();
		}
		
		return value;
	}
	
	private void defragment()
	{
		drawCount += drawCountSinceDefrag;
		rejectionCount += rejectionCountSinceDefrag;
		nullCount += nullCountSinceDefrag;
		
		// Remove all null values from lookup table
		// To do this, start from end, removing nulls as we go,
		// and moving non-nulls to spaces on the free list.
		int freeSize = freeQueue.size();
		for(int i = lookupTable.size() - 1; i >= 0 && freeSize > 0; i--)
		{
			T value = lookupTable.get(i);
			Set<Integer> locations = locationMap.get(value);
			if(value != null)
			{
				// Get a free spot in the lookup table.
				// Indices in the queue will be valid unless
				// they were removed from the end of the table
				// in the previous loop.
				int freeIndex;
				do
				{
					freeIndex = freeQueue.remove(0);
				} while(freeIndex >= lookupTable.size());
				
				// Move the value to the free index
				lookupTable.set(freeIndex, value);
				
				locations.remove(i);
				locations.add(freeIndex);
			}

			lookupTable.remove(i);
			freeSize--;
		}
		
		assert freeSize == 0;
		
		freeQueue.clear();
		
		drawCountSinceDefrag = 0;
		rejectionCountSinceDefrag = 0;
		nullCountSinceDefrag = 0;
	}

	public void remove(T value)
	{
		if(locationMap.containsKey(value))
		{
			Set<Integer> locations = locationMap.get(value);
			
			for(int location : locations)
			{
				lookupTable.set(location, null);
				freeQueue.add(location);
			}
			locationMap.remove(value);
			weightMap.remove(value);
		}
		if(weightMap.size() == 0) totalWeight = 0;
	}

	public void update(T value, double weight)
	{
		update(value, weight, true);
	}
	
	public void update(T value, double weight, boolean updateMap)
	{
		double oldWeight = 0;
		
		if(weightMap.containsKey(value))
		{
			oldWeight = weightMap.get(value);
		}
		
		if(weight <= 0)
		{
			remove(value);
			if(updateMap) totalWeight -= oldWeight;
			return;
		}
		
		// Calculate number of bins to add/remove
		int binCount = (int)Math.ceil(weight/binWeight);
		int binCountDelta;
		Set<Integer> locations;
		if(locationMap.containsKey(value))
		{
			locations = locationMap.get(value);
			int oldBinCount = locations.size();
			binCountDelta = binCount - oldBinCount;
		}
		else
		{
			locations = new HashSet<Integer>();
			locationMap.put(value, locations);
			binCountDelta = binCount;
		}
		
		// If we're adding bins, take them from the free queue unless it's empty
		if(binCountDelta > 0)
		{
			for(int i = 0; i < binCountDelta; i++)
			{
				int location;
				if(freeQueue.isEmpty())
				{
					location = lookupTable.size();
					lookupTable.add(value);
				}
				else
				{
					location = freeQueue.remove(0);
					lookupTable.set(location, value);
				}
				locations.add(location);
			}
		}
		
		// If removing bins, set the locations to null or just remove if they're at the end
		else if(binCountDelta < 0)
		{
			Iterator<Integer> locItr = locations.iterator();
			
			for(int i = 0; i > binCountDelta; i--)
			{
				int location = locItr.next();
				locItr.remove();
				
				if(location == lookupTable.size() - 1)
				{
					lookupTable.remove(location);
				}
				else
				{
					lookupTable.set(location, null);
					freeQueue.add(location);
				}
			}
		}
		
		if(updateMap) // This part is skipped when initializing from an existing map
		{
			// Set the weight
			weightMap.put(value, weight);
			totalWeight += weight - oldWeight;
		}
	}
	
	public Map<T, Double> getWeights()
	{
		return weightMap;
	}
	
	public double getTotalWeight()
	{
		return totalWeight;
	}
	
	public double getRejectionRate()
	{
		return (double)(rejectionCount + rejectionCountSinceDefrag)/(drawCount + drawCountSinceDefrag);
	}

	public double getNullRate()
	{
		return (double)(nullCount + nullCountSinceDefrag)/(drawCount + drawCountSinceDefrag);
	}
	
	public double getTotalRejectionRate()
	{
		return (double)(rejectionCount + rejectionCountSinceDefrag + nullCount + nullCountSinceDefrag)/(drawCount + drawCountSinceDefrag);
	}
}
