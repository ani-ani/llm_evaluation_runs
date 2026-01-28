import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
MAX_ELEMENTS = 8
OUTPUT_WIDTH = 24
CLK_NS = 10
MAX_CYCLES = 1000

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

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
    if has_signal(dut, 'rst'):
        dut.rst.value = 1
    for _ in range(3):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    if has_signal(dut, 'rst'):
        dut.rst.value = 0
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_cube_nums(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Test cases: (input_array, expected_cube_array, description)
    test_cases = [
        ([1, 2, 3, 4, 5, 6, 7, 8], [1, 8, 27, 64, 125, 216, 343, 512], "Small numbers 1-8"),
        ([10, 20, 30], [1000, 8000, 27000], "Medium numbers"),
        ([12, 15], [1728, 3375], "Two elements"),
        ([255], [16581375], "Max 8-bit value"),
        ([0, 0, 0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 0, 0], "All zeros")
    ]
    
    for test_idx, (input_arr, expected_arr, desc) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {test_idx + 1}: {desc}")
        cocotb.log.info(f"  Input: {input_arr}")
        cocotb.log.info(f"  Expected: {expected_arr}")
        
        # Reset
        await reset_dut(dut)
        
        # Set array length
        arr_len = len(input_arr)
        if has_signal(dut, 'len'):
            dut.len.value = arr_len
        else:
            # Try len_N style
            for i in range(MAX_ELEMENTS):
                if hasattr(dut, f'len_{i}'):
                    dut.__setattr__(f'len_{i}', 1 if i < arr_len else 0)
        
        # Write input array (element by element)
        for i in range(arr_len):
            dut.arr[i].value = clamp_to_width(input_arr[i], DATA_WIDTH)
        
        # Clear any leftover values for unused elements
        for i in range(arr_len, MAX_ELEMENTS):
            dut.arr[i].value = 0
        
        # Wait one cycle, then start
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Collect results
        collected_results = []
        cycles_passed = 0
        max_cycles_for_test = 200
        
        while cycles_passed < max_cycles_for_test:
            await RisingEdge(dut.clk)
            cycles_passed += 1
            
            # Check if result is valid
            if is_value_defined(dut.result_valid.value) and int(dut.result_valid.value) == 1:
                result_val = int(dut.result.value)
                collected_results.append(result_val)
                cocotb.log.debug(f"  Cycle {cycles_passed}: Got result {result_val}")
            
            # Check if done
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                cocotb.log.info(f"  Done signal received after {cycles_passed} cycles")
                break
        
        # Verify results
        if len(collected_results) != len(expected_arr):
            raise TestFailure(
                f"Test {test_idx + 1} failed: Expected {len(expected_arr)} results, got {len(collected_results)}"
            )
        
        for idx, (got, exp) in enumerate(zip(collected_results, expected_arr)):
            if got != exp:
                raise TestFailure(
                    f"Test {test_idx + 1}, element {idx}: Expected {exp}, got {got}"
                )
        
        cocotb.log.info(f"  ✓ Test {test_idx + 1} passed ({len(collected_results)} results)")
    
    cocotb.log.info("\n=== ALL TESTS PASSED ===")