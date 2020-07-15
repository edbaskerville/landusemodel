package jstoch.util;

import java.util.*;

public class IndexedPriorityQueue<E extends Comparable<E>>
{
	List<E> heap;
	HashMap<E, Integer> indexes;

	public IndexedPriorityQueue()
	{
		heap = new ArrayList<E>();
		indexes = new HashMap<E, Integer>();
	}
	
	public IndexedPriorityQueue(List<E> initObjs)
	{
		heap = new ArrayList<E>(initObjs);
		indexes = new HashMap<E, Integer>(initObjs.size());
		for(int i = 0; i < heap.size(); i++)
		{
			indexes.put(heap.get(i), i);
		}
	}
	
	public E head()
	{
		if(heap.size() > 0) return heap.get(0);
		return null;
	}
	
	public void add(E obj)
	{
		indexes.put(obj, heap.size());
		heap.add(obj);
	}
	
	public void update(int i, E obj)
	{
		if(i < heap.size())
		{
			indexes.remove(heap.get(i));
			indexes.put(obj, i);
			heap.set(i, obj);
			update(i);
		}
		else throw new IndexOutOfBoundsException("Index beyond heap bounds.");
	}
	
	public void update(E obj)
	{
		if(indexes.containsKey(obj))
		{
			update(indexes.get(obj));
		}
		else throw new IllegalArgumentException("Element not present in heap.");
	}
	
	public void update(int i)
	{
		if(!heapifyUp(i))
		{
			heapifyDown(i);
		}
	}
	
	public void buildHeap()
	{
		int maxParentIndex = (heap.size() - 2)/2;
		
		// Make sure a heap exists at all levels, starting at the bottom
		for(int i = maxParentIndex; i >= 0; i--)
		{
			heapifyDown(i);
		}
	}
	
	public boolean heapifyUp(int i)
	{
		boolean moved = false;
		while(i > 0)
		{
			int parent = parent(i);
			if(heap.get(i).compareTo(heap.get(parent)) < 0)
			{
				swap(i, parent);
				i = parent;
				moved = true;
			}
			else break;
		}
		return moved;
	}
	
	public boolean heapifyDown(int i)
	{
		boolean moved = false;
		
		int size = heap.size();
		int maxParentIndex = (size - 2) / 2;
		while(i <= maxParentIndex)
		{
			E nVal = heap.get(i);
			
			int left = left(i);
			if(left >= size) break;
			E leftVal = heap.get(left);
			
			int right = left + 1;
			E rightVal = right < size ? heap.get(right) : null;
			
			int min = i;
			
			if(leftVal.compareTo(nVal) < 0)
			{
				if(rightVal != null && rightVal.compareTo(leftVal) < 0) min = right;
				else min = left;
			}
			else if(rightVal != null && rightVal.compareTo(nVal) < 0)  min = right;
			else break;
			
			moved = true;
			swap(i, min);
			i = min;
		}
		return moved;
	}
	
	private static int parent(int i)
	{
		return (i-1)/2;
	}
	
	private static int left(int i)
	{
		return 2*i + 1;
	}
	
	private void swap(int i1, int i2)
	{
		E e1 = heap.get(i2);
		E e2 = heap.get(i1);
		heap.set(i1, e1);
		heap.set(i2, e2);
		
		indexes.put(e1, i1);
		indexes.put(e2, i2);
	}
	
	public List<E> getHeap()
	{
		return heap;
	}
}
