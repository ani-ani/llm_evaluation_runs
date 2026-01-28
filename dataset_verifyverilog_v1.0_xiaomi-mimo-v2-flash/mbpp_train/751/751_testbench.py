import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants
DATA_WIDTH = 8
ARRAY_SIZE = 16
LEN_WIDTH = 5
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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_array(dut, arr_name, values, width):
    """Write array elements individually"""
    for i, v in enumerate(values):
        dut.__getattr__(arr_name)[i].value = clamp_to_width(v, width)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_min_heap_checker(dut):
    """Test min-heap checker module"""
    
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (array, length, expected_result, description)
    test_cases = [
        ([1, 2, 3, 4, 5, 6], 6, 1, "Valid heap"),
        ([2, 3, 4, 5, 10, 15], 6, 1, "Valid heap 2"),
        ([2, 10, 4, 5, 3, 15], 6, 0, "Invalid heap"),
        ([5], 1, 1, "Single element"),
        ([1, 2, 3], 3, 1, "Three elements"),
        ([3, 1, 2], 3, 0, "Invalid root"),
        ([1, 3, 2, 5, 4], 5, 1, "Valid heap with two children"),
        ([1, 5, 2, 6, 4, 3], 6, 1, "Valid heap reordered"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (arr_vals, arr_len, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        
        try:
            # Write array elements
            for j, val in enumerate(arr_vals):
                dut.arr[j].value = clamp_to_width(val, DATA_WIDTH)
            
            # Write length
            dut.len.value = clamp_to_width(arr_len, LEN_WIDTH)
            
            # Start operation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut, 100)
            
            # Check result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined")
            
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"PASS: {desc}")
            passed += 1
            
            # Wait for done to go low before next test
            await RisingEdge(dut.clk)
            if int(dut.done.value) == 1:
                await RisingEdge(dut.clk)
                
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    
    cocotb.log.info(f"All tests passed: {passed}")
