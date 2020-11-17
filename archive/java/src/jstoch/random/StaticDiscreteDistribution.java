package jstoch.random;

import cern.jet.random.AbstractDiscreteDistribution;
import cern.jet.random.engine.RandomEngine;

/**
 * Represents custom discrete probability distributions that do not change
 * in time. Current implementation simply uses the rejection algorithm.
 * 
 * @author Ed Baskerville
 *
 */
@SuppressWarnings("serial")
public class StaticDiscreteDistribution extends AbstractDiscreteDistribution
{
	RandomEngine rng;
	double[] weights;
	int count;
	double maxWeight;
	
	public StaticDiscreteDistribution(double[] weights, RandomEngine rng)
	{
		if(weights.length == 0) throw new IllegalArgumentException("Array of weights must not be empty.");
		
		this.weights = weights;
		count = weights.length;
		this.rng = rng;
		
		maxWeight = 0;
		for(double weight : weights)
		{
			if(weight <= 0)
			{
				throw new IllegalArgumentException("Weights must be positive.");
			}
			
			if(weight > maxWeight)
				maxWeight = weight;
		}
	}
	
	@Override
	public int nextInt()
	{
		// Simple implementation of standard rejection method.
		boolean accepted = false;
		int value = -1;
		while(!accepted)
		{
			value = Math.abs(rng.nextInt()) % count; 
			if(rng.nextDouble() * maxWeight < weights[value])
			{
				accepted = true;
			}
		}
		return value;
	}
}
