import cocotb
from cocotb.triggers import Timer
import itertools

MOD = 1000000009

def is_element_sorted(perm, k):
    """Check if element at index k is sorted in permutation perm"""
    for j in range(k+1, len(perm)):
        if perm[j] < perm[k]:
            return False
    for j in range(k):
        if perm[j] > perm[k]:
            return False
    return True

def count_entirely_unsorted(arr):
    """Count permutations where no element is sorted"""
    n = len(arr)
    count = 0
    # Generate all permutations (with duplicate handling)
    for perm in set(itertools.permutations(arr)):
        is_entirely_unsorted = True
        for k in range(n):
            if is_element_sorted(perm, k):
                is_entirely_unsorted = False
                break
        if is_entirely_unsorted:
            count += 1
    return count % MOD

@cocotb.test()
async def test_unsorted_permutations(dut):
    """Test unsorted permutations calculation"""
    
    # Test case 1: [0,1,2,3] -> 14
    dut.n.value = 4
    dut.data[0].value = 0
    dut.data[1].value = 1
    dut.data[2].value = 2
    dut.data[3].value = 3
    await Timer(10, units='ns')
    result = int(dut.count.value)
    expected = count_entirely_unsorted([0,1,2,3])
    assert result == expected, f"Test 1 failed: expected {expected}, got {result}"
    print(f"Test 1 passed: [0,1,2,3] -> {result}")
    
    # Test case 2: [1,1,2,1,1] -> 1
    dut.n.value = 5
    dut.data[0].value = 1
    dut.data[1].value = 1
    dut.data[2].value = 2
    dut.data[3].value = 1
    dut.data[4].value = 1
    await Timer(10, units='ns')
    result = int(dut.count.value)
    expected = count_entirely_unsorted([1,1,2,1,1])
    assert result == expected, f"Test 2 failed: expected {expected}, got {result}"
    print(f"Test 2 passed: [1,1,2,1,1] -> {result}")
    
    # Test case 3: [1,2,3,4,5,6,7,8] -> 40320 (8! = 40320, all permutations work for distinct sorted sequence? No)
    # Actually for strictly increasing sequence, only 1,2,3,4,5,6,7,8 in that order has sorted elements
    # Let's compute properly using Python
    dut.n.value = 8
    for i in range(8):
        dut.data[i].value = i+1
    await Timer(10, units='ns')
    result = int(dut.count.value)
    expected = count_entirely_unsorted([1,2,3,4,5,6,7,8])
    assert result == expected, f"Test 3 failed: expected {expected}, got {result}"
    print(f"Test 3 passed: [1,2,3,4,5,6,7,8] -> {result}")
    
    # Test case 4: Single element [42] -> 0 (the only element is always sorted)
    dut.n.value = 1
    dut.data[0].value = 42
    await Timer(10, units='ns')
    result = int(dut.count.value)
    expected = count_entirely_unsorted([42])
    assert result == expected, f"Test 4 failed: expected {expected}, got {result}"
    print(f"Test 4 passed: [42] -> {result}")
    
    # Test case 5: [1,2,1] -> 0 (all permutations have at least one sorted element)
    dut.n.value = 3
    dut.data[0].value = 1
    dut.data[1].value = 2
    dut.data[2].value = 1
    await Timer(10, units='ns')
    result = int(dut.count.value)
    expected = count_entirely_unsorted([1,2,1])
    assert result == expected, f"Test 5 failed: expected {expected}, got {result}"
    print(f"Test 5 passed: [1,2,1] -> {result}")
    
    print(f"
All tests completed successfully!")
