import cocotb
from cocotb.triggers import Timer
import random

def calculate_rate(data, start, length):
    """Calculate success rate for subsequence data[start:start+length]"""
    segment = data[start:start+length]
    ones = segment.count('1')
    return (ones, length)

def find_best_subsequence(data_str, k):
    """Brute force find best subsequence"""
    best_f = 0
    best_l = 0
    best_num = -1
    best_den = -1
    
    n = len(data_str)
    
    # Try all valid subsegments
    for start in range(n):
        for length in range(k, n - start + 1):
            end = start + length
            segment = data_str[start:end]
            ones = segment.count('1')
            
            # Compare rates: a/b > c/d if a*d > c*b
            if best_num == -1:
                best_num = ones
                best_den = length
                best_f = start
                best_l = length
            else:
                if ones * best_den > best_num * length:
                    best_num = ones
                    best_den = length
                    best_f = start
                    best_l = length
                elif ones * best_den == best_num * length:
                    # Tie-breaker: smaller start index
                    if start < best_f:
                        best_num = ones
                        best_den = length
                        best_f = start
                        best_l = length
                    elif start == best_f:
                        # Tie-breaker: longer length
                        if length > best_l:
                            best_num = ones
                            best_den = length
                            best_f = start
                            best_l = length
    
    return best_f, best_l

@cocotb.test()
async def test_best_subsequence(dut):
    """Test the best_subsequence module"""
    
    # Test case 1: k=1, data="01" -> Expect start=1, len=1 (rate 1/1 > 0/1)
    dut.k.value = 1
    dut.data.value = 0b01
    dut.n.value = 2
    await Timer(10, units='ns')
    assert int(dut.start_index) == 1, f"Test 1 failed: expected start=1, got {int(dut.start_index)}"
    assert int(dut.length) == 1, f"Test 1 failed: expected length=1, got {int(dut.length)}"
    print("Test 1 passed: k=1, data=01 -> start=1, len=1")
    
    # Test case 2: k=4, data="0110011" (7 bits)
    # Find best subsequence of length >= 4
    # Data: 0 1 1 0 0 1 1
    # Indices:0 1 2 3 4 5 6
    # We need to check lengths 4, 5, 6, 7
    # Best is probably the last 6 characters (indices 1-6): 110011 -> 4 ones / 6 = 0.667
    # Or length 5: 11001 -> 3/5 = 0.6
    # Or length 4: 1100 -> 2/4 = 0.5
    # Or length 7: 0110011 -> 4/7 = 0.571
    # Best is 110011 (start=1, len=6) with 4/6 = 0.667
    dut.k.value = 4
    dut.data.value = 0b0110011
    dut.n.value = 7
    await Timer(10, units='ns')
    # For tie-breaking, verify start and length match expected
    assert int(dut.start_index) == 1, f"Test 2 failed: expected start=1, got {int(dut.start_index)}"
    assert int(dut.length) == 6, f"Test 2 failed: expected length=6, got {int(dut.length)}"
    print("Test 2 passed: k=4, data=0110011 -> start=1, len=6")
    
    # Test case 3: All zeros
    dut.k.value = 3
    dut.data.value = 0b00000000
    dut.n.value = 8
    await Timer(10, units='ns')
    # All have rate 0, should pick first valid (start=0, len=8 or start=0, len=3?)
    # Tie-breaker: prefer smaller start (0), then longer (8 vs 3 -> 8 wins)
    assert int(dut.start_index) == 0, f"Test 3 failed: expected start=0, got {int(dut.start_index)}"
    # All rates equal 0, tie-breaker: smaller start, then longer
    # So length should be 8 (full range)
    assert int(dut.length) == 8, f"Test 3 failed: expected length=8, got {int(dut.length)}"
    print("Test 3 passed: k=3, data=00000000 -> start=0, len=8")
    
    # Test case 4: All ones
    dut.k.value = 2
    dut.data.value = 0b11111111
    dut.n.value = 8
    await Timer(10, units='ns')
    # All rates 1.0, pick smallest start (0), longest (8)
    assert int(dut.start_index) == 0, f"Test 4 failed: expected start=0, got {int(dut.start_index)}"
    assert int(dut.length) == 8, f"Test 4 failed: expected length=8, got {int(dut.length)}"
    print("Test 4 passed: k=2, data=11111111 -> start=0, len=8")
    
    # Test case 5: Mixed pattern - corner case
    dut.k.value = 5
    dut.data.value = 0b0011110011001100  # 16 bits
    dut.n.value = 16
    await Timer(10, units='ns')
    expected_f, expected_l = find_best_subsequence("0011110011001100", 5)
    assert int(dut.start_index) == expected_f, f"Test 5 failed: expected start={expected_f}, got {int(dut.start_index)}"
    assert int(dut.length) == expected_l, f"Test 5 failed: expected length={expected_l}, got {int(dut.length)}"
    print(f"Test 5 passed: k=5, data=0011110011001100 -> start={expected_f}, len={expected_l}")
    
    print("
All tests passed!")
