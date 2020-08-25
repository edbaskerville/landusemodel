package jstoch.model;

public interface RateFunction
{
	double getRate(int total, int... reactantPopulations);
}
