import cocotb
from cocotb.triggers import Timer
import random

def calculate_max_length(tubes, L1, L2):
    """Calculate maximum total length for 4 tubes fitting constraints"""
    n = len(tubes)
    max_total = -1
    
    # Try all combinations of 4 distinct tubes
    for i in range(n):
        for j in range(i+1, n):
            sum1 = tubes[i] + tubes[j]
            if sum1 > L1:
                continue
            for k in range(n):
                if k == i or k == j:
                    continue
                for l in range(k+1, n):
                    if l == i or l == j:
                        continue
                    sum2 = tubes[k] + tubes[l]
                    if sum2 <= L2:
                        total = tubes[i] + tubes[j] + tubes[k] + tubes[l]
                        if total > max_total:
                            max_total = total
    
    return max_total

@cocotb.test()
async def test_vacuum_tubes(dut):
    """Test vacuum tube selection module"""
    
    # Test case 1: Basic working case
    dut.L1.value = 50  # Scaled from 1000
    dut.L2.value = 100 # Scaled from 2000
    dut.valid_count.value = 7
    tubes = [5, 24, 25, 28, 50, 70, 75]  # Scaled from [100,480,500,550,1000,1400,1500]
    for i in range(8):
        if i < len(tubes):
            setattr(dut, f'tube_{i}').value = tubes[i]
        else:
            setattr(dut, f'tube_{i}').value = 0
    
    await Timer(10, units='ns')
    
    expected = calculate_max_length(tubes, 50, 100)
    observed = dut.total_length.value.integer
    impossible = dut.impossible.value
    
    if expected == -1:
        assert impossible == 1, f"Test 1: Expected impossible=1, got {impossible}"
    else:
        assert impossible == 0, f"Test 1: Expected impossible=0, got {impossible}"
        assert observed == expected, f"Test 1: Expected {expected}, got {observed}"
    print(f"Test 1: {'PASSED' if (expected == -1 and impossible == 1) or (expected != -1 and impossible == 0 and observed == expected) else 'FAILED'}")
    
    # Test case 2: No valid solution (Impossible)
    dut.L1.value = 10
    dut.L2.value = 15
    dut.valid_count.value = 6
    tubes = [10, 10, 10, 10, 10, 10]
    for i in range(8):
        if i < len(tubes):
            getattr(dut, f'tube_{i}').value = tubes[i]
        else:
            getattr(dut, f'tube_{i}').value = 0
    
    await Timer(10, units='ns')
    
    expected = calculate_max_length(tubes, 10, 15)
    observed = dut.total_length.value.integer
    impossible = dut.impossible.value
    
    if expected == -1:
        assert impossible == 1, f"Test 2: Expected impossible=1, got {impossible}"
    else:
        assert impossible == 0, f"Test 2: Expected impossible=0, got {impossible}"
        assert observed == expected, f"Test 2: Expected {expected}, got {observed}"
    print(f"Test 2: {'PASSED' if (expected == -1 and impossible == 1) or (expected != -1 and impossible == 0 and observed == expected) else 'FAILED'}")
    
    # Test case 3: Edge case with 4 tubes
    dut.L1.value = 20
    dut.L2.value = 20
    dut.valid_count.value = 4
    tubes = [5, 6, 7, 8]
    for i in range(8):
        if i < len(tubes):
            getattr(dut, f'tube_{i}').value = tubes[i]
        else:
            getattr(dut, f'tube_{i}').value = 0
    
    await Timer(10, units='ns')
    
    expected = calculate_max_length(tubes, 20, 20)
    observed = dut.total_length.value.integer
    impossible = dut.impossible.value
    
    if expected == -1:
        assert impossible == 1, f"Test 3: Expected impossible=1, got {impossible}"
    else:
        assert impossible == 0, f"Test 3: Expected impossible=0, got {impossible}"
        assert observed == expected, f"Test 3: Expected {expected}, got {observed}"
    print(f"Test 3: {'PASSED' if (expected == -1 and impossible == 1) or (expected != -1 and impossible == 0 and observed == expected) else 'FAILED'}")
    
    # Test case 4: Edge case with 8 tubes, optimal at boundary
    dut.L1.value = 50
    dut.L2.value = 50
    dut.valid_count.value = 8
    tubes = [10, 10, 10, 10, 20, 20, 20, 20]
    for i in range(8):
        getattr(dut, f'tube_{i}').value = tubes[i]
    
    await Timer(10, units='ns')
    
    expected = calculate_max_length(tubes, 50, 50)
    observed = dut.total_length.value.integer
    impossible = dut.impossible.value
    
    if expected == -1:
        assert impossible == 1, f"Test 4: Expected impossible=1, got {impossible}"
    else:
        assert impossible == 0, f"Test 4: Expected impossible=0, got {impossible}"
        assert observed == expected, f"Test 4: Expected {expected}, got {observed}"
    print(f"Test 4: {'PASSED' if (expected == -1 and impossible == 1) or (expected != -1 and impossible == 0 and observed == expected) else 'FAILED'}")
    
    # Test case 5: Randomized test
    random.seed(42)
    tubes = [random.randint(5, 50) for _ in range(8)]
    L1 = random.randint(30, 80)
    L2 = random.randint(30, 80)
    
    dut.L1.value = L1
    dut.L2.value = L2
    dut.valid_count.value = 8
    for i in range(8):
        getattr(dut, f'tube_{i}').value = tubes[i]
    
    await Timer(10, units='ns')
    
    expected = calculate_max_length(tubes, L1, L2)
    observed = dut.total_length.value.integer
    impossible = dut.impossible.value
    
    if expected == -1:
        assert impossible == 1, f"Test 5: Expected impossible=1, got {impossible}"
    else:
        assert impossible == 0, f"Test 5: Expected impossible=0, got {impossible}"
        assert observed == expected, f"Test 5: Expected {expected}, got {observed}"
    print(f"Test 5: {'PASSED' if (expected == -1 and impossible == 1) or (expected != -1 and impossible == 0 and observed == expected) else 'FAILED'}")
    
    # Summary
    print("
All tests completed!")
