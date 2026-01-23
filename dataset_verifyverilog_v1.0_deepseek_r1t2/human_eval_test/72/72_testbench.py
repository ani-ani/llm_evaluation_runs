import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

async def wait_for_done(dut, max_cycles=20):
    """Wait for done signal to go high, with cycle timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_will_it_fly(dut):
    """Test will_it_fly module with adapted test cases."""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(3):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases adapted for 4-element max size
    # Format: (array_values, length, w, expected_result, description)
    test_cases = [
        ([3, 2, 3, 0], 3, 9, 1, "Balanced (3,2,3), sum=8 <= 9"),
        ([1, 2, 0, 0], 2, 5, 0, "Unbalanced (1,2)"),
        ([3, 0, 0, 0], 1, 5, 1, "Single element, balanced, sum=3 <= 5"),
        ([3, 2, 3, 0], 3, 1, 0, "Balanced but sum=8 > 1"),
        ([1, 2, 3, 0], 3, 6, 0, "Unbalanced (1,2,3)"),
        ([5, 0, 0, 0], 1, 5, 1, "Single element, sum=5 <= 5"),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (arr_vals, length, w_val, expected, desc) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}: {desc}")
        
        # Setup inputs
        dut.len.value = length
        dut.w.value = w_val
        
        # Assign array elements
        for j in range(4):
            dut.arr[j].value = arr_vals[j]
        
        # Assert start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut, max_cycles=15)
        
        # Check result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {i+1}: Result is undefined (X/Z)")
        
        result = int(dut.result.value)
        if result != expected:
            raise TestFailure(f"Test {i+1}: Expected {expected}, got {result}. {desc}")
        
        passed += 1
        await RisingEdge(dut.clk)
    
    dut._log.info(f"Summary: {passed}/{total} tests passed")
    if passed != total:
        raise TestFailure(f"Only {passed}/{total} tests passed")
