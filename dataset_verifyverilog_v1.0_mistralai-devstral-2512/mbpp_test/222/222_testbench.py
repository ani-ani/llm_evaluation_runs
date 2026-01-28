import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants
DATA_WIDTH = 8
ARRAY_SIZE = 8
CLK_NS = 10
MAX_CYCLES = 1000

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except (ValueError, TypeError):
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except (ValueError, TypeError):
        return default

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    v_int = int(v)
    return min(max_val, max(0, v_int))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut, cycles=2):
    """Reset the DUT synchronously"""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=100):
    """Wait for done signal to be asserted"""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_array(dut, name, values, width):
    """Write values to array elements individually"""
    for i, v in enumerate(values):
        if i >= ARRAY_SIZE:
            break
        arr_elem = getattr(dut, name)[i]
        arr_elem.value = clamp_to_width(v, width)

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_type_check(dut):
    """Test the type checking module"""
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        clock = Clock(dut.clk, CLK_NS, units='ns')
        cocotb.start_soon(clock.start())
        await reset_dut(dut)
    
    # Test cases: (input_array, expected_result, description)
    test_cases = [
        ([5, 6, 7, 3, 5, 6], 0, "Mixed values - should be 0"),
        ([1, 2, 4], 0, "Different values - should be 0"),
        ([3, 2, 1, 4, 5], 0, "Different values - should be 0"),
        ([5, 5, 5, 5], 1, "All same - should be 1"),
        ([0, 0, 0, 0, 0, 0, 0, 0], 1, "All zeros - should be 1"),
        ([42], 1, "Single element - should be 1"),
        ([7, 7], 1, "Two elements same - should be 1"),
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, (inp_array, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {test_idx + 1}: {description}")
        cocotb.log.info(f"  Input array: {inp_array}")
        cocotb.log.info(f"  Expected result: {expected}")
        
        try:
            await write_array(dut, 'arr', inp_array, DATA_WIDTH)
            
            if has_signal(dut, 'len'):
                dut.len.value = len(inp_array)
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut, max_cycles=100)
            else:
                await Timer(100, units='ns')
            
            if not is_value_defined(dut.result.value):
                raise TestFailure(f"Result undefined for test '{description}'")
            
            result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(
                    f"Test '{description}': Expected {expected}, got {result}"
                )
            
            cocotb.log.info(f"  Result: {result} ✓")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
        except Exception as e:
            cocotb.log.error(f"Unexpected error: {e}")
            failed += 1
    
    cocotb.log.info(f"\nTest Summary: {passed} passed, {failed} failed")
    
    if failed > 0:
        raise TestFailure(f"{failed} out of {passed + failed} tests failed")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_edge_cases(dut):
    """Test edge cases"""
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        clock = Clock(dut.clk, CLK_NS, units='ns')
        cocotb.start_soon(clock.start())
        await reset_dut(dut)
    
    cocotb.log.info("Testing empty array (len=0)")
    await write_array(dut, 'arr', [1, 2, 3], DATA_WIDTH)
    
    if has_signal(dut, 'len'):
        dut.len.value = 0
    
    if is_seq:
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await wait_for_done(dut, max_cycles=100)
    else:
        await Timer(100, units='ns')
    
    if is_value_defined(dut.result.value):
        result = int(dut.result.value)
        if result != 1:
            raise TestFailure(f"Empty array should return 1, got {result}")
        cocotb.log.info(f"  Result: {result} ✓")
    
    cocotb.log.info("Testing maximum length array (8 elements)")
    await write_array(dut, 'arr', [10, 10, 10, 10, 10, 10, 10, 10], DATA_WIDTH)
    
    if has_signal(dut, 'len'):
        dut.len.value = 8
    
    if is_seq:
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await wait_for_done(dut, max_cycles=100)
    else:
        await Timer(100, units='ns')
    
    if is_value_defined(dut.result.value):
        result = int(dut.result.value)
        if result != 1:
            raise TestFailure(f"All same with 8 elements should return 1, got {result}")
        cocotb.log.info(f"  Result: {result} ✓")
    
    cocotb.log.info("Testing maximum length with difference")
    await write_array(dut, 'arr', [1, 2, 3, 4, 5, 6, 7, 8], DATA_WIDTH)
    
    if has_signal(dut, 'len'):
        dut.len.value = 8
    
    if is_seq:
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await wait_for_done(dut, max_cycles=100)
    else:
        await Timer(100, units='ns')
    
    if is_value_defined(dut.result.value):
        result = int(dut.result.value)
        if result != 0:
            raise TestFailure(f"Different values with 8 elements should return 0, got {result}")
        cocotb.log.info(f"  Result: {result} ✓")