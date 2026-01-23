import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer
from cocotb.result import TestFailure

def encode_sublist(sublist):
    """Encode a Python list as a 32-bit ID (4x8-bit integers)"""
    padded = sublist + [0] * (4 - len(sublist))
    return (padded[0] << 24) | (padded[1] << 16) | (padded[2] << 8) | padded[3]

def count_unique_sublists(sublists):
    """Reference implementation for test cases"""
    from collections import defaultdict
    counts = defaultdict(int)
    for sl in sublists:
        padded = tuple(sl + [0] * (4 - len(sl)))
        counts[padded] += 1
    return counts

@cocotb.test()
async def test_unique_sublists_basic(dut):
    """Test 1: Basic counting with duplicates"""
    # Input: [[1, 3], [5, 7], [1, 3], [13, 15, 17], [5, 7], [9, 11]]
    # Adapted: 6 sublists, each padded to 4 elements
    sublists_input = [
        [1, 3, 0, 0],
        [5, 7, 0, 0],
        [1, 3, 0, 0],
        [13, 15, 17, 0],
        [5, 7, 0, 0],
        [9, 11, 0, 0]
    ]
    
    # Set inputs
    for i in range(8):
        if i < len(sublists_input):
            for j in range(4):
                dut.sublists[i][j].value = sublists_input[i][j]
        else:
            for j in range(4):
                dut.sublists[i][j].value = 0
    
    dut.valid_count.value = len(sublists_input)
    
    # Wait for combinational logic to settle
    await Timer(10, units='ns')
    
    # Expected results
    expected = count_unique_sublists(sublists_input)
    expected_ids = sorted([encode_sublist(list(k)) for k in expected.keys()])
    expected_counts = [expected[k] for k in sorted(expected.keys(), key=lambda x: sublists_input.index(list(x))) if encode_sublist(list(k)) in expected_ids]
    expected_unique_count = len(expected)
    
    # Read outputs
    actual_unique_count = int(dut.unique_count.value)
    
    # Verify count
    if actual_unique_count != expected_unique_count:
        raise TestFailure(f"Expected {expected_unique_count} unique sublists, got {actual_unique_count}")
    
    # Verify each unique entry
    actual_ids = []
    actual_counts = []
    for i in range(actual_unique_count):
        actual_ids.append(int(dut.unique_ids[i].value))
        actual_counts.append(int(dut.counts[i].value))
    
    # Check if results match (order may vary)
    for i in range(expected_unique_count):
        if actual_counts[i] != expected_counts[i]:
            raise TestFailure(f"Count mismatch at index {i}: expected {expected_counts[i]}, got {actual_counts[i]}")
    
    print(f"Test 1 Passed: Found {actual_unique_count} unique sublists with correct counts")

@cocotb.test()
async def test_unique_sublists_strings(dut):
    """Test 2: String sublists (encoded as integers)"""
    # Strings: 'green'=0, 'orange'=1, 'black'=2, 'white'=3
    # [[0,1], [2], [0,1], [3]]
    sublists_input = [
        [0, 1, 0, 0],  # 'green', 'orange'
        [2, 0, 0, 0],  # 'black'
        [0, 1, 0, 0],  # 'green', 'orange'
        [3, 0, 0, 0]   # 'white'
    ]
    
    for i in range(8):
        if i < len(sublists_input):
            for j in range(4):
                dut.sublists[i][j].value = sublists_input[i][j]
        else:
            for j in range(4):
                dut.sublists[i][j].value = 0
    
    dut.valid_count.value = len(sublists_input)
    await Timer(10, units='ns')
    
    actual_unique_count = int(dut.unique_count.value)
    if actual_unique_count != 4:
        raise TestFailure(f"Expected 4 unique sublists, got {actual_unique_count}")
    
    # Verify counts
    counts = [int(dut.counts[i].value) for i in range(actual_unique_count)]
    expected_counts = [2, 1, 1, 0]  # [0,1]:2, [2]:1, [3]:1
    
    for i in range(3):
        if counts[i] != expected_counts[i]:
            raise TestFailure(f"Count mismatch: expected {expected_counts[i]}, got {counts[i]}")
    
    print(f"Test 2 Passed: Found {actual_unique_count} unique sublists with correct counts")

@cocotb.test()
async def test_unique_sublists_all_unique(dut):
    """Test 3: All sublists unique"""
    sublists_input = [
        [1, 2, 0, 0],
        [3, 4, 0, 0],
        [4, 5, 0, 0],
        [6, 7, 0, 0]
    ]
    
    for i in range(8):
        if i < len(sublists_input):
            for j in range(4):
                dut.sublists[i][j].value = sublists_input[i][j]
        else:
            for j in range(4):
                dut.sublists[i][j].value = 0
    
    dut.valid_count.value = len(sublists_input)
    await Timer(10, units='ns')
    
    actual_unique_count = int(dut.unique_count.value)
    if actual_unique_count != 4:
        raise TestFailure(f"Expected 4 unique sublists, got {actual_unique_count}")
    
    # All counts should be 1
    for i in range(actual_unique_count):
        count = int(dut.counts[i].value)
        if count != 1:
            raise TestFailure(f"Expected count 1, got {count}")
    
    print(f"Test 3 Passed: All {actual_unique_count} sublists unique")

@cocotb.test()
async def test_unique_sublists_edge_case(dut):
    """Test 4: Single unique sublist with high count"""
    sublists_input = [
        [42, 99, 0, 0],
        [42, 99, 0, 0],
        [42, 99, 0, 0],
        [42, 99, 0, 0]
    ]
    
    for i in range(8):
        if i < len(sublists_input):
            for j in range(4):
                dut.sublists[i][j].value = sublists_input[i][j]
        else:
            for j in range(4):
                dut.sublists[i][j].value = 0
    
    dut.valid_count.value = len(sublists_input)
    await Timer(10, units='ns')
    
    actual_unique_count = int(dut.unique_count.value)
    if actual_unique_count != 1:
        raise TestFailure(f"Expected 1 unique sublist, got {actual_unique_count}")
    
    count = int(dut.counts[0].value)
    if count != 4:
        raise TestFailure(f"Expected count 4, got {count}")
    
    print(f"Test 4 Passed: Single unique sublist with count 4")

@cocotb.test()
async def test_unique_sublists_full_sublists(dut):
    """Test 5: Full 4-element sublists"""
    sublists_input = [
        [1, 2, 3, 4],
        [5, 6, 7, 8],
        [1, 2, 3, 4],
        [9, 10, 11, 12]
    ]
    
    for i in range(8):
        if i < len(sublists_input):
            for j in range(4):
                dut.sublists[i][j].value = sublists_input[i][j]
        else:
            for j in range(4):
                dut.sublists[i][j].value = 0
    
    dut.valid_count.value = len(sublists_input)
    await Timer(10, units='ns')
    
    actual_unique_count = int(dut.unique_count.value)
    if actual_unique_count != 3:
        raise TestFailure(f"Expected 3 unique sublists, got {actual_unique_count}")
    
    # Should have counts: [1,2,3,4]=2, [5,6,7,8]=1, [9,10,11,12]=1
    counts = [int(dut.counts[i].value) for i in range(actual_unique_count)]
    if sorted(counts) != [1, 1, 2]:
        raise TestFailure(f"Expected counts [1,1,2], got {sorted(counts)}")
    
    print(f"Test 5 Passed: Full-width sublists counted correctly")

@cocotb.test()
async def test_unique_sublists_max_count(dut):
    """Test 6: Maximum 8 sublists"""
    sublists_input = [
        [1, 0, 0, 0], [2, 0, 0, 0], [1, 0, 0, 0], [3, 0, 0, 0],
        [2, 0, 0, 0], [4, 0, 0, 0], [1, 0, 0, 0], [5, 0, 0, 0]
    ]
    
    for i in range(8):
        for j in range(4):
            dut.sublists[i][j].value = sublists_input[i][j]
    
    dut.valid_count.value = 8
    await Timer(10, units='ns')
    
    actual_unique_count = int(dut.unique_count.value)
    if actual_unique_count != 5:
        raise TestFailure(f"Expected 5 unique sublists, got {actual_unique_count}")
    
    # Verify counts: [1]=3, [2]=2, [3]=1, [4]=1, [5]=1
    counts = [int(dut.counts[i].value) for i in range(actual_unique_count)]
    if sorted(counts) != [1, 1, 1, 2, 3]:
        raise TestFailure(f"Expected counts [1,1,1,2,3], got {sorted(counts)}")
    
    print(f"Test 6 Passed: Maximum 8 sublists processed correctly")
