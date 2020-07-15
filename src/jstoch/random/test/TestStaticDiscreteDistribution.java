package jstoch.random.test;

import jstoch.random.StaticDiscreteDistribution;

import org.junit.*;
import static org.junit.Assert.*;

import cern.jet.random.engine.MersenneTwister;
import cern.jet.random.engine.RandomEngine;

/**
 * Test case for StaticDiscreteDistribution class.
 * 
 * @author Ed Baskerville
 *
 */
public class TestStaticDiscreteDistribution
{
	private RandomEngine rng;
	private StaticDiscreteDistribution dist;
	
	@Before
	public void setUp() throws Exception
	{
		rng = new MersenneTwister();
	}

	@After
	public void tearDown() throws Exception
	{
	}
	
	@Test
	public void emptyDist()
	{
		double[] weights = new double[0];
		try
		{
			dist = new StaticDiscreteDistribution(weights, rng);
			fail();
		}
		catch(IllegalArgumentException e) {}
	}
	
	@Test
	public void singleDist()
	{
		double[] weights = new double[] { 0.5 };
		dist = new StaticDiscreteDistribution(weights, rng);
		
		int value = dist.nextInt();
		assertEquals(value, 0);
	}
	
	@Test
	public void multipleDistUniform()
	{
		double[] weights = new double[] { 0.5, 0.5, 0.5, 0.5 };
		dist = new StaticDiscreteDistribution(weights, rng);
		
		int[] counts = new int[4];
		
		for(int i = 0; i < 100; i++)
		{
			counts[dist.nextInt()]++;
		}

		for(int i = 0; i < 4; i++)
		{
			assertTrue("Count " + i + " not in expected range: " + counts[i],
					counts[i] > 20 && counts[i] < 30);
		}
	}
	
	@Test
	public void multipleDistVariable()
	{
		double[] weights = new double[] { 0.1, 0.2, 0.7 };
		dist = new StaticDiscreteDistribution(weights, rng);
		
		int[] counts = new int[3];
		
		for(int i = 0; i < 1000; i++)
		{
			counts[dist.nextInt()]++;
		}
		
		assertTrue("counts[0] = " + counts[0], counts[0] > 80 && counts[0] < 120);
		assertTrue("counts[1] = " + counts[1], counts[1] > 160 && counts[1] < 240);
		assertTrue("counts[2] = " + counts[2], counts[2] > 660 && counts[2] < 840);
	}
}
