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


def to_signed(val, bits=8):
    """Convert unsigned to signed representation."""
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val


def from_signed(val, bits=8):
    """Convert signed to unsigned for assignment."""
    if val < 0:
        return val + (1 << bits)
    return val


@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_can_arrange(dut):
    """Test the can_arrange module with various test cases."""
    
    # Setup clock and reset
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.len.value = 0
    for i in range(8):
        dut.arr[i].value = 0
    
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (array_values, expected_result, description)
    test_cases = [
        ([1, 2, 4, 3, 5], 3, "example 1: decrease at index 3"),
        ([1, 2, 4, 5], -1, "example 2: no decrease"),
        ([1, 4, 2, 5, 6, 7, 8, 9], 2, "example 3: decrease at index 2"),
        ([4, 8, 5, 7, 3], 4, "example 4: decrease at index 4"),
        ([1, 2, 3], -1, "edge case: increasing sequence"),
        ([], -1, "edge case: empty array"),
        ([5], -1, "edge case: single element"),
        ([9, 1], 1, "edge case: immediate decrease at index 1"),
        ([1, 3, 5, 7, 2, 4, 6, 8], 4, "full array: decrease at index 4"),
        ([2, 1], 1, "two elements: decrease at index 1"),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (array_vals, expected, description) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}: {description}")
        
        # Load array into DUT
        dut.len.value = len(array_vals)
        for j in range(8):
            if j < len(array_vals):
                dut.arr[j].value = from_signed(array_vals[j], 8)
            else:
                dut.arr[j].value = 0
        
        # Wait a bit for inputs to settle
        await Timer(10, units="ns")
        
        # Pulse start signal
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal with cycle timeout
        max_cycles = 20
        done_received = False
        for cycle in range(max_cycles):
            await RisingEdge(dut.clk)
            
            # Check if done is defined
            if not is_value_defined(dut.done.value):
                continue
            
            if dut.done.value == 1:
                done_received = True
                break
        
        if not done_received:
            raise TestFailure(f"Test {i+1}: Done signal not asserted after {max_cycles} cycles")
        
        # Verify result is defined
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {i+1}: Result has undefined value (X/Z)")
        
        # Read and check result
        result = to_signed(int(dut.result.value), 8)
        
        if result == expected:
            dut._log.info(f"  PASS: result={result}, expected={expected}")
            passed += 1
        else:
            dut._log.error(f"  FAIL: result={result}, expected={expected}")
            raise TestFailure(f"Test {i+1}: expected {expected}, got {result}")
        
        # Wait for next test
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
    
    dut._log.info(f"\n=== Summary: {passed}/{total} tests passed ===")
    if passed != total:
        raise TestFailure(f"Only {passed}/{total} tests passed")
