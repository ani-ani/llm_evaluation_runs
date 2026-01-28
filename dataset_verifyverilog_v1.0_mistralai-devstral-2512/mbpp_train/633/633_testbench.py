import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants
DATA_WIDTH = 8
ARRAY_SIZE = 16
LEN_WIDTH = 4
RESULT_WIDTH = 32
CLK_NS = 10
MAX_CYCLES = 300

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    if v < 0:
        return 0
    return min(max_val, v)

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

async def write_array(dut, name, values, width):
    """Write values to array elements individually"""
    for i, v in enumerate(values):
        if i < ARRAY_SIZE:
            getattr(dut, f"{name}_{i}").value = clamp_to_width(v, width)

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_pair_xor_sum(dut):
    """Test the pair XOR sum module with various test cases"""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases
    test_cases = [
        ([5, 9, 7, 6], 4, 47, "Test 1: [5,9,7,6]"),
        ([7, 3, 5], 3, 12, "Test 2: [7,3,5]"),
        ([7, 3], 2, 4, "Test 3: [7,3]"),
        ([0, 0, 0], 3, 0, "Test 4: zeros"),
        ([255], 1, 0, "Test 5: single element"),
        ([1, 2, 3, 4, 5], 5, 40, "Test 6: 5 elements")
    ]
    
    passed = 0
    failed = 0
    
    for test_num, (arr, arr_len, expected, desc) in enumerate(test_cases, 1):
        cocotb.log.info(f"Running {desc}")
        
        try:
            # Write array values
            for i in range(min(arr_len, ARRAY_SIZE)):
                dut.arr[i].value = clamp_to_width(arr[i], DATA_WIDTH)
            
            # Set length
            dut.len.value = arr_len
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for completion
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"  PASS: result={result}")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        # Reset between tests
        await RisingEdge(dut.clk)
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    if failed:
        raise TestFailure(f"\n{failed} test(s) failed, {passed} passed")
    else:
        cocotb.log.info(f"\nAll {passed} tests passed!")
