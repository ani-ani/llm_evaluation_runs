import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

def to_signed_16bit(value):
    """Convert Python int to signed 16-bit representation"""
    if value < 0:
        return (value + 65536) & 0xFFFF
    return value & 0xFFFF

@cocotb.test()
async def test_rotation_counter(dut):
    """Test rotation counter with various test cases"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        # (array, expected_rotations, description)
        ([3, 2, 1], 1, "Test 1: [3,2,1] -> 1 rotation"),
        ([4, 5, 1, 2, 3], 2, "Test 2: [4,5,1,2,3] -> 2 rotations"),
        ([7, 8, 9, 1, 2, 3], 3, "Test 3: [7,8,9,1,2,3] -> 3 rotations"),
        ([1, 2, 3], 0, "Test 4: [1,2,3] -> 0 rotations"),
        ([1, 3, 2], 2, "Test 5: [1,3,2] -> 2 rotations"),
        ([1], 0, "Edge: single element"),
        ([5, 1], 1, "Edge: two elements [5,1]"),
        ([1, 5], 0, "Edge: two elements [1,5]"),
        ([2, 2, 2, 1], 3, "Edge: duplicates with min at end"),
        ([1, 1, 1, 1], 0, "Edge: all equal")
    ]
    
    passed = 0
    total = len(test_cases)
    
    for arr, expected, description in test_cases:
        # Load array
        n = len(arr)
        dut.n.value = n
        
        # Fill array (pad with zeros)
        for i in range(16):
            if i < n:
                dut.arr[i].value = to_signed_16bit(arr[i])
            else:
                dut.arr[i].value = 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 20
        cycles = 0
        while not dut.done.value and cycles < timeout:
            await RisingEdge(dut.clk)
            cycles += 1
        
        if cycles >= timeout:
            raise TestFailure(f"Timeout for {description}")
        
        # Read result
        result = int(dut.rotations.value)
        
        if result == expected:
            print(f"PASS: {description} - Got {result}")
            passed += 1
        else:
            print(f"FAIL: {description} - Expected {expected}, Got {result}")
    
    print(f"
Summary: {passed}/{total} tests passed")
    
    if passed < total:
        raise TestFailure(f"Only {passed}/{total} tests passed")
