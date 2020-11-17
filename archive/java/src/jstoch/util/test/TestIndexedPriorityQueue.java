package jstoch.util.test;

import java.util.*;

import jstoch.util.*;

import org.junit.*;
import static org.junit.Assert.*;

@SuppressWarnings("unchecked")
public class TestIndexedPriorityQueue
{
	IndexedPriorityQueue queue;
	
	@Test
	public void heapifySimple()
	{
		List<Integer> preHeap = new EasyList<Integer>(9, 1, 2, 3, 5, 7, 8);
		queue = new IndexedPriorityQueue<Integer>(preHeap);
		queue.heapifyDown(0);
		assertEquals(new EasyList<Integer>(1, 3, 2, 9, 5, 7, 8), queue.getHeap());
	}
	
	@Test
	public void heapifyIncomplete()
	{
		List<Integer> preHeap = new EasyList<Integer>(9, 1, 2, 3);
		queue = new IndexedPriorityQueue<Integer>(preHeap);
		queue.heapifyDown(0);
		assertEquals(new EasyList<Integer>(1, 3, 2, 9), queue.getHeap());
	}
	
	@Test
	public void heapifyStupid()
	{
		List<Integer> preHeap = new EasyList<Integer>(9, 1, 2, 3, 5, 7, 8);
		queue = new IndexedPriorityQueue<Integer>(preHeap);
		queue.heapifyDown(3);
		assertEquals(new EasyList<Integer>(9, 1, 2, 3, 5, 7, 8), queue.getHeap());
	}
	
	@Test
	public void heapifyNonzeroIndex()
	{
		List<Integer> preHeap = new EasyList<Integer>(1, 9, 2, 3, 5, 7, 8);
		queue = new IndexedPriorityQueue<Integer>(preHeap);
		queue.heapifyDown(1);
		assertEquals(new EasyList<Integer>(1, 3, 2, 9, 5, 7, 8), queue.getHeap());
	}
	
	@Test
	public void heapifyBorderlineIndex()
	{
		List<Integer> preHeap = new EasyList<Integer>(1, 2, 9, 3, 4, 5, 6);
		queue = new IndexedPriorityQueue<Integer>(preHeap);
		queue.heapifyDown(2);
		assertEquals(new EasyList<Integer>(1, 2, 5, 3, 4, 9, 6), queue.getHeap());
	}
	
	@Test
	public void heapifyUp()
	{
		List<Integer> preHeap = new EasyList<Integer>(1, 2, 3, 4, 0, 5, 6);
		queue = new IndexedPriorityQueue<Integer>(preHeap);
		queue.heapifyUp(4);
		assertEquals(new EasyList<Integer>(0, 1, 3, 4, 2, 5, 6), queue.getHeap());
	}
	
	@Test
	public void buildHeapReverse()
	{
		List<Integer> preHeap = new EasyList<Integer>(8, 7, 6, 5, 4, 3, 2, 1);
		
		queue = new IndexedPriorityQueue<Integer>(preHeap);
		queue.buildHeap();
		
		assertEquals(new EasyList<Integer>(1, 4, 2, 5, 8, 3, 6, 7), queue.getHeap());
	}
	
	@Test
	public void updateUp()
	{
		queue = new IndexedPriorityQueue<Integer>(new EasyList<Integer>(1, 2, 3, 4, 5, 6, 7));
		queue.update(5, 0);
		assertEquals(new EasyList<Integer>(0, 2, 1, 4, 5, 3, 7), queue.getHeap());
	}
	
	@Test
	public void updateDown()
	{
		queue = new IndexedPriorityQueue<Integer>(new EasyList<Integer>(1, 2, 3, 4, 5, 6, 7));
		queue.update(0, 5);
		assertEquals(new EasyList<Integer>(2, 4, 3, 5, 5, 6, 7), queue.getHeap());
	}
	
	@Test
	public void testInfinity()
	{
		assertTrue(5.0 < Double.POSITIVE_INFINITY);
	}
	
	@Test
	public void testInfinityInQueue()
	{
		queue = new IndexedPriorityQueue<Double>(
				new EasyList<Double>(1., 2., Double.POSITIVE_INFINITY, 3., 4., 5., 6.));
		queue.buildHeap();
		assertEquals(new EasyList<Double>(1., 2., 5., 3., 4., Double.POSITIVE_INFINITY, 6.),
				queue.getHeap());
	}
}
