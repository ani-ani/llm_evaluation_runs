import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def to_signed(val, bits):
    """Convert unsigned to signed representation."""
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    """Convert signed to unsigned for assignment."""
    if val < 0:
        return val + (1 << bits)
    return val

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_min_subarray_sum(dut):
    """Test minSubArraySum module with various test cases."""
    
    # Setup clock and reset
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    for i in range(8):
        dut.arr[i].value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases with scaled values for 16-bit signed range
    # Format: (input_array, expected_output)
    test_cases = [
        ([2, 3, 4, 1, 2, 4, 0, 0], 1),
        ([-1, -2, -3, 0, 0, 0, 0, 0], -6),
        ([-1, -2, -3, 2, -10, 0, 0, 0], -14),
        ([-99, -99, -99, -99, -99, -99, -99, -99], -99),  # Scaled from -9999999999999999
        ([0, 10, 20, 100, 0, 0, 0, 0], 0),
        ([-1, -2, -3, 10, -5, 0, 0, 0], -6),
        ([100, -1, -2, -3, 10, -5, 0, 0], -6),
        ([10, 11, 13, 8, 3, 4, 0, 0], 3),
        ([100, -33, 32, -1, 0, -2, 0, 0], -33),
        ([-10, 0, 0, 0, 0, 0, 0, 0], -10),
        ([7, 0, 0, 0, 0, 0, 0, 0], 7),
        ([1, -1, 0, 0, 0, 0, 0, 0], -1),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for idx, (input_array, expected) in enumerate(test_cases):
        dut._log.info(f"Test case {idx+1}: {input_array} -> expected {expected}")
        
        # Load input array
        for i in range(8):
            dut.arr[i].value = from_signed(input_array[i], 16)
        
        # Assert start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion with cycle-based timeout
        done_seen = False
        for cycle in range(20):  # Allow extra cycles for safety
            await RisingEdge(dut.clk)
            
            if not is_value_defined(dut.done.value):
                continue
            
            if dut.done.value == 1:
                done_seen = True
                break
        
        if not done_seen:
            raise TestFailure(f"Test {idx+1}: Done signal not asserted within timeout")
        
        # Verify output is defined
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {idx+1}: Result is undefined (X/Z)")
        
        # Read and convert result
        result_unsigned = int(dut.result.value)
        result = to_signed(result_unsigned, 16)
        
        if result != expected:
            raise TestFailure(f"Test {idx+1}: expected {expected}, got {result}")
        
        passed += 1
        dut._log.info(f"Test case {idx+1} passed")
        
        # Small delay between tests
        await Timer(50, units="ns")
        await RisingEdge(dut.clk)
    
    dut._log.info(f"\nSummary: {passed}/{total} tests passed")
    if passed != total:
        raise TestFailure(f"Only {passed} of {total} tests passed")
