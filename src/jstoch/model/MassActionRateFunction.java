package jstoch.model;

public class MassActionRateFunction implements RateFunction
{
	private double rateConstant;
	private DensityMethod densityMethod;
	private int numReactants;
	
	public MassActionRateFunction(double rateConstant, int numReactants, DensityMethod densityMethod)
	{
		this.rateConstant = rateConstant;
		this.numReactants = numReactants;
		this.densityMethod = densityMethod;
	}
	
	public int getNumberOfReactants()
	{
		return numReactants;
	}

	public double getRate(int total, int... populations)
	{
		double rate = rateConstant;
		for(int i = 0; i < numReactants; i++)
		{
			rate *= populations[i];
			switch(densityMethod)
			{
				case Fractional:
					rate /= total;
					break;
			}
		}
		
		return rate;
	}
}
