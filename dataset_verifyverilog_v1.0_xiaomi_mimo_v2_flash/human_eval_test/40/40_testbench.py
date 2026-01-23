import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def to_signed_8bit(val):
    """Convert Python int to 8-bit signed representation."""
    if val < 0:
        return val + 256
    return val & 0xFF

def check_triples_sum(arr, length):
    """Reference implementation in Python."""
    for i in range(length):
        for j in range(i + 1, length):
            for k in range(j + 1, length):
                if arr[i] + arr[j] + arr[k] == 0:
                    return 1
    return 0

@cocotb.test(timeout_time=5, timeout_unit="ms")
async def test_triples_sum_to_zero(dut):
    """Test triples_sum_to_zero module."""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.len.value = 0
    for i in range(8):
        dut.arr[i].value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (array_values, length, expected_result, test_name)
    test_cases = [
        ([1, 3, 5, 0], 4, 0, "No zero sum"),
        ([1, 3, 5, -1], 4, 0, "No zero sum 2"),
        ([1, 3, -2, 1], 4, 1, "Has zero sum: 1+3-2=2, 1+3-4=0? No, 3-2+1=2... wait: -2+1+1=0"),
        ([1, 2, 3, 7], 4, 0, "No zero sum 3"),
        ([1, 2, 5, 7], 4, 0, "No zero sum 4"),
        ([2, 4, -5, 3, 9, 7], 6, 1, "Has zero sum: 2+3-5=0"),
        ([1], 1, 0, "Single element"),
        ([1, 3, 5, -100], 4, 0, "Large negative"),
        ([100, 3, 5, -100], 4, 0, "100+3+5-100=8, not zero"),
        ([0, 0, 0], 3, 1, "All zeros"),
        ([-10, 5, 5], 3, 1, "Negative first"),
        ([10, -5, -5], 3, 1, "Positive first"),
        ([10, 20, -30], 3, 1, "Simple zero sum"),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for arr_vals, length, expected, name in test_cases:
        # Load array
        for i in range(8):
            if i < length:
                dut.arr[i].value = to_signed_8bit(arr_vals[i])
            else:
                dut.arr[i].value = 0
        
        dut.len.value = length
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done with timeout
        max_cycles = 1000
        done_found = False
        for cycle in range(max_cycles):
            await RisingEdge(dut.clk)
            if not is_value_defined(dut.done.value):
                continue
            if dut.done.value == 1:
                done_found = True
                break
        
        if not done_found:
            raise TestFailure(f"Test '{name}': Timeout - done signal not asserted after {max_cycles} cycles")
        
        # Check result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test '{name}': Result is undefined (X/Z)")
        
        actual = int(dut.result.value)
        if actual != expected:
            raise TestFailure(f"Test '{name}': expected {expected}, got {actual} for array {arr_vals[:length]}")
        
        dut._log.info(f"Test '{name}': PASSED (result={actual})")
        passed += 1
        
        # Small gap between tests
        await RisingEdge(dut.clk)
    
    dut._log.info(f"\n=== SUMMARY: {passed}/{total} tests passed ===")
    if passed != total:
        raise TestFailure(f"Only {passed} of {total} tests passed")
