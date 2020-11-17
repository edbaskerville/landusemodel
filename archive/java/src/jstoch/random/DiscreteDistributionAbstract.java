package jstoch.random;

import java.util.*;

public abstract class DiscreteDistributionAbstract<T> implements
		DiscreteDistribution<T>
{
	public boolean verify(int numDraws)
	{
		Map<T, Integer> counts = new HashMap<T, Integer>();
		
		for(int i = 0; i < numDraws; i++)
		{
			T value = nextValue();
			Integer count = counts.get(value);
			if(count == null)
			{
				counts.put(value, 1);
			}
			else
			{
				counts.put(value, count + 1);
			}
		}
		
		// Get total weight
		double totalWeight = 0;
		for(double weight : getWeights().values())
		{
			totalWeight += weight;
		}
		
		// Calculate SSE
		double sumSqErr = 0;
		for(T value : getWeights().keySet())
		{
			int count = counts.get(value) == null ? 0 : counts.get(value);
			
			double err = getWeight(value) / totalWeight - (double)count / numDraws;
			sumSqErr += err * err;
		}
		
		System.err.println("Verify called: SSE = " + sumSqErr);
		
		// Make sure SSE is less than an order of magnitude
		// greater than 1/numDraws
		if(sumSqErr > 6.0/numDraws)
		{
			return false;
		}
		return true;
	}
}
