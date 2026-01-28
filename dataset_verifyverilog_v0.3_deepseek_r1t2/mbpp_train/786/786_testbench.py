import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 8
ARRAY_SIZE = 8
RESULT_WIDTH = 4
CLK_PERIOD_NS = 10
MAX_CYCLES = 50

# Helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

async def write_array(dut, values):
    """Write sorted array to DUT."""
    for i in range(ARRAY_SIZE):
        if i < len(values):
            dut.arr[i].value = clamp_to_width(values[i], DATA_WIDTH)
        else:
            dut.arr[i].value = 0

async def reset_dut(dut):
    """Reset the DUT."""
    dut.rst_n.value = 0
    if hasattr(dut, 'start'):
        dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut):
    """Wait for done signal with timeout."""
    for cycle in range(MAX_CYCLES):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {MAX_CYCLES} cycles")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_right_insertion(dut):
    """Test binary search right insertion point."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (array, length, target, expected_result, description)
    test_cases = [
        ([1, 2, 4, 5], 4, 6, 4, "Insert 6 in [1,2,4,5] -> index 4"),
        ([1, 2, 4, 5], 4, 3, 2, "Insert 3 in [1,2,4,5] -> index 2"),
        ([1, 2, 4, 5], 4, 7, 4, "Insert 7 in [1,2,4,5] -> index 4"),
        ([1, 2, 4, 5], 4, 1, 1, "Insert 1 in [1,2,4,5] -> index 1"),
        ([5, 10, 15], 3, 12, 2, "Insert 12 in [5,10,15] -> index 2"),
        ([1, 2, 3], 3, 0, 0, "Insert 0 in [1,2,3] -> index 0"),
        ([10, 20], 2, 20, 2, "Insert 20 in [10,20] -> index 2"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (arr, arr_len, target, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        
        try:
            # Write inputs
            await write_array(dut, arr)
            dut.arr_len.value = arr_len
            dut.target.value = target
            await RisingEdge(dut.clk)
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")