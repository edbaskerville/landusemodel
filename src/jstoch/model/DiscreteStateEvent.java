package jstoch.model;

public interface DiscreteStateEvent<T> extends Event
{
	T getStartState();
	T getEndState();
	T[] getReactants();
	RateFunction getRateFunction();
}
