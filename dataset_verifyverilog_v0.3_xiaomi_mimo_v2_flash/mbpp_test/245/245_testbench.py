import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 8
RESULT_WIDTH = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 500

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

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_bitonic_max_sum(dut):
    """Test bitonic maximum sum module"""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (input_array, expected_result)
    test_cases = [
        ([1, 15, 51, 45, 33, 100, 12, 18], 194),  # Test 1 (using 8 elements)
        ([80, 60, 30, 40, 20, 10, 0, 0], 210),   # Test 2 (padded with zeros)
        ([2, 3, 14, 16, 21, 23, 29, 30], 138),   # Test 3 (padded)
        ([1, 2, 3, 4, 5, 6, 7, 8], 36),          # Increasing sequence
        ([8, 7, 6, 5, 4, 3, 2, 1], 36),          # Decreasing sequence
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_arr, expected) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: Input = {input_arr}, Expected = {expected}")
        
        try:
            # Write inputs to individual ports
            dut.arr_0.value = clamp_to_width(input_arr[0], DATA_WIDTH)
            dut.arr_1.value = clamp_to_width(input_arr[1], DATA_WIDTH)
            dut.arr_2.value = clamp_to_width(input_arr[2], DATA_WIDTH)
            dut.arr_3.value = clamp_to_width(input_arr[3], DATA_WIDTH)
            dut.arr_4.value = clamp_to_width(input_arr[4], DATA_WIDTH)
            dut.arr_5.value = clamp_to_width(input_arr[5], DATA_WIDTH)
            dut.arr_6.value = clamp_to_width(input_arr[6], DATA_WIDTH)
            dut.arr_7.value = clamp_to_width(input_arr[7], DATA_WIDTH)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for completion
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
    
    # Summary
    cocotb.log.info(f"\n{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")