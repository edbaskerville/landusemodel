package jstoch.random;

import java.util.Map;

public interface DiscreteDistribution<T>
{
	public void update(T value, double weight);
	public void remove(T value);
	public double getWeight(T value);
	public T nextValue();
	public int getSize();
	
	public Map<T, Double> getWeights();
	
	public double getTotalWeight();
	
	public double getRejectionRate();
	public double getNullRate();
	public double getTotalRejectionRate();
	
	public boolean verify(int numDraws);
}
