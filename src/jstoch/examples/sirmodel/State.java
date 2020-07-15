package jstoch.examples.sirmodel;

public enum State
{
	Susceptible(0xFF00FF00),
	Infected(0xFFFF0000),
	Recovered(0xFF0000FF);
	
	private int color;
	
	State(int color)
	{
		this.color = color;
	}
	
	public int color()
	{
		return color;
	}
}
