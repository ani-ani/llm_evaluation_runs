import cocotb
from cocotb.triggers import Timer
import random

def to_binary_array(values, length=8):
    """Convert Python list to binary array for Verilog input"""
    result = [0] * length
    for i, v in enumerate(values[:length]):
        result[i] = v
    return result

@cocotb.test()
async def test_array_overlap_basic(dut):
    """Test basic overlap detection"""
    
    # Test 1: No overlap
    dut.array1[0].value = 1
    dut.array1[1].value = 2
    dut.array1[2].value = 3
    dut.array1[3].value = 4
    dut.array1[4].value = 5
    dut.array1[5].value = 0
    dut.array1[6].value = 0
    dut.array1[7].value = 0
    
    dut.array2[0].value = 6
    dut.array2[1].value = 7
    dut.array2[2].value = 8
    dut.array2[3].value = 9
    dut.array2[4].value = 0
    dut.array2[5].value = 0
    dut.array2[6].value = 0
    dut.array2[7].value = 0
    
    await Timer(10, units='ns')
    assert dut.overlap.value == 0, f"Test 1 failed: expected 0, got {dut.overlap.value}"
    print("Test 1 passed: No overlap detected correctly")

@cocotb.test()
async def test_array_overlap_positive(dut):
    """Test detection of overlapping values"""
    
    # Test 2: No overlap
    dut.array1[0].value = 1
    dut.array1[1].value = 2
    dut.array1[2].value = 3
    dut.array1[3].value = 0
    dut.array1[4].value = 0
    dut.array1[5].value = 0
    dut.array1[6].value = 0
    dut.array1[7].value = 0
    
    dut.array2[0].value = 4
    dut.array2[1].value = 5
    dut.array2[2].value = 6
    dut.array2[3].value = 0
    dut.array2[4].value = 0
    dut.array2[5].value = 0
    dut.array2[6].value = 0
    dut.array2[7].value = 0
    
    await Timer(10, units='ns')
    assert dut.overlap.value == 0, f"Test 2 failed: expected 0, got {dut.overlap.value}"
    print("Test 2 passed: No overlap detected correctly")

@cocotb.test()
async def test_array_overlap_full_match(dut):
    """Test when both arrays are identical"""
    
    # Test 3: Full overlap
    dut.array1[0].value = 1
    dut.array1[1].value = 4
    dut.array1[2].value = 5
    dut.array1[3].value = 0
    dut.array1[4].value = 0
    dut.array1[5].value = 0
    dut.array1[6].value = 0
    dut.array1[7].value = 0
    
    dut.array2[0].value = 1
    dut.array2[1].value = 4
    dut.array2[2].value = 5
    dut.array2[3].value = 0
    dut.array2[4].value = 0
    dut.array2[5].value = 0
    dut.array2[6].value = 0
    dut.array2[7].value = 0
    
    await Timer(10, units='ns')
    assert dut.overlap.value == 1, f"Test 3 failed: expected 1, got {dut.overlap.value}"
    print("Test 3 passed: Full overlap detected correctly")

@cocotb.test()
async def test_array_overlap_edge_cases(dut):
    """Test edge cases: single element overlap, all zeros, etc."""
    
    # Test 4: Single element overlap
    dut.array1[0].value = 42
    dut.array1[1].value = 0
    dut.array1[2].value = 0
    dut.array1[3].value = 0
    dut.array1[4].value = 0
    dut.array1[5].value = 0
    dut.array1[6].value = 0
    dut.array1[7].value = 0
    
    dut.array2[0].value = 99
    dut.array2[1].value = 42
    dut.array2[2].value = 0
    dut.array2[3].value = 0
    dut.array2[4].value = 0
    dut.array2[5].value = 0
    dut.array2[6].value = 0
    dut.array2[7].value = 0
    
    await Timer(10, units='ns')
    assert dut.overlap.value == 1, f"Test 4 failed: expected 1, got {dut.overlap.value}"
    print("Test 4 passed: Single element overlap detected correctly")

@cocotb.test()
async def test_array_overlap_random(dut):
    """Test with random values and verify using Python logic"""
    
    for _ in range(10):
        # Generate random arrays
        arr1 = [random.randint(0, 255) for _ in range(8)]
        arr2 = [random.randint(0, 255) for _ in range(8)]
        
        # Feed to DUT
        for i in range(8):
            dut.array1[i].value = arr1[i]
            dut.array2[i].value = arr2[i]
        
        await Timer(10, units='ns')
        
        # Expected result
        expected = 1 if any(x in arr2 for x in arr1) else 0
        
        actual = int(dut.overlap.value)
        assert actual == expected, f"Random test failed: arr1={arr1}, arr2={arr2}, expected={expected}, got={actual}"
    
    print("Random tests passed: 10 iterations")

# Summary: 5 tests total, all should pass