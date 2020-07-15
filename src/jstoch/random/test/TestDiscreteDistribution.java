/**
 * 
 */
package jstoch.random.test;


import jstoch.random.*;

import org.junit.*;

import static org.junit.Assert.*;

import cern.jet.random.engine.*;

/**
 * Test case for DynamicDiscreteDistribution class.
 * 
 * @author Ed Baskerville
 */
public class TestDiscreteDistribution
{
	RandomEngine rng;
	DiscreteDistribution<Integer> dist;
	
	@Before
	public void setUp() throws Exception
	{
		rng = new MersenneTwister();
		//dist = new DiscreteDistributionRejection<Integer>(rng);
		dist = new DiscreteDistributionRejectionPlus<Integer>(0.1, rng);
	}
	
	@After
	public void tearDown() throws Exception
	{
	}
	
	@Test
	public void emptyDist()
	{
		assertEquals(null, dist.nextValue());
	}
	
	@Test
	public void singleDistNoChange()
	{
		dist.update(1, 0.5);
		
		int value = dist.nextValue();
		assertEquals(value, 1);
	}
	
	@Test
	public void multipleDistUniformNoChange()
	{
		for(int i = 0; i < 4; i++) dist.update(i, 0.5);
		
		int[] counts = new int[4];
		
		for(int i = 0; i < 1000; i++)
		{
			counts[dist.nextValue()]++;
		}

		for(int i = 0; i < 4; i++)
		{
			assertTrue("Count " + i + " not in expected range: " + counts[i],
					counts[i] > 200 && counts[i] < 300);
		}
	}
	
	@Test
	public void multipleDistUniformRemoval()
	{
		for(int i = 0; i < 4; i++)
		{
			dist.update(i, 0.5);
		}
		
		dist.remove(2);
		
		int[] counts = new int[4];
		
		for(int i = 0; i < 1000; i++)
		{
			counts[dist.nextValue()]++;
		}

		
		assertTrue("Count 2 should be zero", counts[2] == 0);
		for(int i = 0; i < 4; i++)
		{
			if(i != 2)
			{
				assertTrue("Count " + i + " not in expected range: " + counts[i],
						counts[i] > 250 && counts[i] < 410); 
			}
		}
	}
	
	@Test
	public void multipleDistVariableRemoval()
	{
		dist.update(0, 0.5);
		dist.update(1, 0.1);
		dist.update(2, 0.2);
		dist.update(3, 0.7);
		
		dist.remove(0);
		
		int[] counts = new int[4];
		
		for(int i = 0; i < 1000; i++)
		{
			counts[dist.nextValue()]++;
		}
		
		assertTrue("counts[0] = " + counts[0], counts[0] == 0);
		assertTrue("counts[1] = " + counts[1], counts[1] >= 80 && counts[0] <= 120);
		assertTrue("counts[2] = " + counts[2], counts[2] >= 160 && counts[1] <= 240);
		assertTrue("counts[3] = " + counts[3], counts[3] >= 660 && counts[2] <= 840);
	}
	
	@Test
	public void multipleDistVariableRemovalAndAddition()
	{
		dist.update(0, 0.5);
		dist.update(1, 0.1);
		dist.update(2, 0.2);
		
		dist.remove(0);
		dist.update(3, 0.7);
		
		int[] counts = new int[4];
		
		for(int i = 0; i < 1000; i++)
		{
			counts[dist.nextValue()]++;
		}
		
		assertTrue("counts[0] = " + counts[0], counts[0] == 0);
		assertTrue("counts[1] = " + counts[1], counts[1] >= 80 && counts[0] <= 120);
		assertTrue("counts[2] = " + counts[2], counts[2] >= 160 && counts[1] <= 240);
		assertTrue("counts[3] = " + counts[3], counts[3] >= 660 && counts[2] <= 840);
	}
	
	@Test
	public void multipleDistUpdate()
	{
		dist.update(0, 0.1);
		dist.update(1, 0.2);
		dist.update(2, 0.5);
		dist.update(2, 0.7);
		
		int[] counts = new int[3];
		
		for(int i = 0; i < 1000; i++)
		{
			counts[dist.nextValue()]++;
		}
		
		assertTrue("counts[0] = " + counts[0], counts[0] > 80 && counts[0] < 120);
		assertTrue("counts[1] = " + counts[1], counts[1] > 160 && counts[1] < 240);
		assertTrue("counts[2] = " + counts[2], counts[2] > 660 && counts[2] < 840);
	}
	
	@Test
	public void stochasticTest()
	{
		double[] weightsStatic = new double[] { 1.0, 0.5 };
		StaticDiscreteDistribution staticDist = new StaticDiscreteDistribution(weightsStatic, rng);
		
		
		for(int i = 0; i < 50; i++)
		{
			dist.update(i, rng.nextDouble());
		}
		
		for(int i = 0; i < 100; i++)
		{
			int value = Math.abs(rng.nextInt()) % 100;
			
			switch(staticDist.nextInt())
			{
				case 0:
					dist.update(value, rng.nextDouble());
					break;
				case 1:
					dist.remove(value);
			}
			
			assertTrue(dist.verify(10000));
			
			System.err.println("Rejection rate " + dist.getRejectionRate());
			System.err.println("Null rate " + dist.getNullRate());
		}
	}
}
