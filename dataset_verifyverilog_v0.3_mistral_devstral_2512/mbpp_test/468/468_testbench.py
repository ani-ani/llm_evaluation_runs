import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 8
ARRAY_SIZE = 8
RESULT_WIDTH = 32
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_max_product(dut):
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (array, len, expected, description)
    test_cases = [
        ([3, 100, 4, 5, 150, 6], 6, 3000, "Case 1: [3,100,4,5,150,6] -> 3000"),
        ([4, 42, 55, 68, 80], 5, 50265600, "Case 2: [4,42,55,68,80] -> 50265600"),
        ([10, 22, 9, 33, 21, 50, 41, 60], 8, 2460, "Case 3: [10,22,9,33,21,50,41,60] -> 2460"),
    ]
    
    for i, (arr_vals, arr_len, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {description}")
        
        # Pad array with zeros if needed
        padded_arr = arr_vals + [0] * (8 - len(arr_vals))
        
        # Write inputs
        for j in range(8):
            getattr(dut, f'arr_{j}').value = padded_arr[j]
        dut.len.value = arr_len
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        await wait_for_done(dut)
        
        # Read result
        result = int(dut.result.value)
        
        # Verify
        if result != expected:
            raise TestFailure(f"Test {i+1} failed: expected {expected}, got {result}")
        
        cocotb.log.info(f"  PASS: result = {result}")
        
        # Reset for next test
        await reset_dut(dut)
    
    cocotb.log.info(f"\n{'='*50}")
    cocotb.log.info(f"All {len(test_cases)} tests passed!")
