package jstoch.random;

import cern.jet.random.engine.*;
import java.util.*;

import static jstoch.util.MathUtils.*;

/**
 * Represents a discrete probability distribution that changes in time.
 * 
 * @author Ed Baskerville
 */
public class DiscreteDistributionRejection<T> extends DiscreteDistributionAbstract<T>
{
	private double totalWeight;
	
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
	 * Tracks maximum weight used in rejection calculation.
	 */
	double maxWeight;
	int maxWeightScale;
	
	/**
	 * Lookup table: stores values corresponding to this location.
	 */
	private List<T> lookupTable;
	
	/**
	 * Map between values and weights.
	 */
	private Map<T, Double> weightMap;
	
	/**
	 * Map between floor(log2(weight)) and number of values with that scale.
	 * Used to determine when to update maxRate.
	 */
	private Map<Integer, Integer> scaleCounts;
	
	/**
	 * Queue of free locations in lookup table.
	 */
	private List<Integer> freeQueue;
	
	/**
	 * Map between values and locations in lookup table.
	 */
	private Map<T, Integer> locationMap;
	
	public DiscreteDistributionRejection(RandomEngine rng)
	{
		this(null, rng);
	}
	
	public DiscreteDistributionRejection(HashMap<T, Double> weights, RandomEngine rng)
	{
		totalWeight = 0;
		
		maxWeight = 0;
		maxWeightScale = Integer.MIN_VALUE;
		
		if(weights != null)
		{
			weightMap = weights;
		}
		else
		{
			weightMap = new HashMap<T, Double>();
		}
		lookupTable = new ArrayList<T>(weightMap.size());
		scaleCounts = new HashMap<Integer, Integer>();
		freeQueue = new LinkedList<Integer>();
		locationMap = new HashMap<T, Integer>(weightMap.size());
		
		this.rng = rng;
		
		for(T value : weightMap.keySet())
		{
			double weight = weights.get(value);
			update(value, weights.get(value), false);
			totalWeight += weight;
		}
	}
	
	public void update(T value, double weight)
	{
		update(value, weight, true);
	}
	
	public void update(T value, double weight, boolean updateMap)
	{
		if(weight <= 0)
		{
			remove(value);
			return;
		}
		
		// Get the current weight and location if the lookup table already
		// contains this value.
		int location = -1;
		double oldWeight = 0;
		if(weightMap.containsKey(value))
		{
			location = locationMap.get(value);
			oldWeight = weightMap.get(value);
		}
		else
		{
			// If there are any free locations, use one of them.
			if(!freeQueue.isEmpty())
			{
				location = freeQueue.remove(0);
			}
			
			// Final option: use the end of the lookup table.
			else
			{
				location = lookupTable.size();
				lookupTable.add(value);
			}
			
			// Update location map appropriately.
			locationMap.put(value, location);
		}
		
		// For all cases: update weight map and lookup table.
		if(updateMap) // Don't do this during initialization from existing map
		{
			weightMap.put(value, weight);
			totalWeight += weight - oldWeight;
		}
		lookupTable.set(location, value);
		
		// Update scale data, and recalculate maxWeight if the scale has changed
		if(updateMap)
		{
			int oldScale = oldWeight == 0 ? Integer.MIN_VALUE : log2Scale(oldWeight);
			int scale = log2Scale(weight);
			
			if(oldScale != scale)
			{
				int oldScaleCount = 0;
				if(oldWeight != 0)
				{
					oldScaleCount = scaleCounts.get(oldScale) - 1;
					scaleCounts.put(oldScale, oldScaleCount);
				}
				
				int scaleCount;
				if(scaleCounts.containsKey(scale))
				{
					scaleCount = scaleCounts.get(scale);
					scaleCounts.put(scale, scaleCount + 1);
				}
				else
				{
					scaleCount = 1;
					scaleCounts.put(scale, 1);
				}
				
				// If the old scale is bigger than the new scale,
				// and there are no weights left at that scale,
				// and that scale is the scale of the currently recorded max weight,
				// it means that the max weight has actually dropped by an order
				// of magnitude, so it might be smart to figure out what the max
				// weight actually is so the rejection rate can go down.
				// Or time trials may reveal this is too much bookkeeping.
				if(oldScale > scale && oldScaleCount == 0 && oldScale == maxWeightScale)
				{
					recalculateMaxWeight();
				}
			}
		}
		
		// Update max weight.
		// This will be just be skipped if the max weight was updated above.
		if(weight > maxWeight)
		{
			maxWeight = weight;
			maxWeightScale = log2Scale(maxWeight);
		}
	}
	
	private void recalculateMaxWeight()
	{
		maxWeight = 0;
		for(double weight : weightMap.values())
		{
			if(weight > maxWeight)
			{
				maxWeight = weight;
			}
		}	
		maxWeightScale = log2Scale(maxWeight);
	}
	
	public void remove(T value)
	{
		if(locationMap.containsKey(value))
		{
			int location = locationMap.get(value);
			lookupTable.set(location, null);
			freeQueue.add(location);
			locationMap.remove(value);
		}
		if(weightMap.containsKey(value))
		{
			totalWeight -= weightMap.get(value);
			weightMap.remove(value);
		}
	}
	
	public double getTotalWeight()
	{
		return totalWeight;
	}
	
	public double getWeight(T value)
	{
		if(!weightMap.containsKey(value)) return 0;
		return weightMap.get(value);
	}
	
	public T nextValue()
	{
		if(weightMap.size() == 0) return null;
		
		// For now: standard rejection method.
		boolean accepted = false;
		T value = null;
		while(!accepted)
		{
			int index = Math.abs(rng.nextInt()) % lookupTable.size();
			value = lookupTable.get(index);
			drawCountSinceDefrag++;
			if(value != null)
			{
				if(rng.nextDouble() * maxWeight < weightMap.get(value))
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
		}
		
		// Complete empirical guess
		if((double)nullCountSinceDefrag / drawCountSinceDefrag > 0.1)
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
				locationMap.put(value, freeIndex);
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
	
	public Map<T, Double> getWeights()
	{
		return weightMap;
	}
	
	public int getSize()
	{
		return weightMap.size();
	}
	
	@Override
	public String toString()
	{
		return weightMap.toString();
	}
	
	public double getRejectionRate()
	{
		return (double)(rejectionCountSinceDefrag + rejectionCount) / (drawCount + drawCountSinceDefrag);
	}
	
	public double getNullRate()
	{
		return (double)(nullCountSinceDefrag + nullCount) / (drawCount + drawCountSinceDefrag);
	}
	
	public double getTotalRejectionRate()
	{
		return (double)(rejectionCount + nullCount + rejectionCountSinceDefrag + nullCountSinceDefrag) / (drawCount + drawCountSinceDefrag);
	}
}
