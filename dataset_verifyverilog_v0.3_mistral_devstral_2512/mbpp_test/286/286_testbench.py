import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Configuration
DATA_WIDTH = 16
ARRAY_SIZE = 8
RESULT_WIDTH = 32
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# Helper functions
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

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    min_val = -(1 << (bits - 1)) if bits > 1 else 0
    if value < 0:
        return value + (1 << bits)
    return min(max_val, value)

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def write_array(dut, values):
    for i in range(ARRAY_SIZE):
        if i < len(values):
            setattr(dut, f'arr_{i}', clamp_to_width(values[i], DATA_WIDTH))
        else:
            setattr(dut, f'arr_{i}', 0)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def run_test(dut, a, n, k, expected):
    # Write array
    await write_array(dut, a)
    
    # Set n and k
    dut.n.value = n
    dut.k.value = k
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    await wait_for_done(dut)
    
    # Read result
    result = int(dut.result.value)
    
    return result

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_max_sub_array_repeated(dut):
    """Test max subarray sum in repeated array"""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases
    test_cases = [
        ([10, 20, -30, -1], 4, 3, 30, "Test 1: [10,20,-30,-1] * 3 = 30"),
        ([-1, 10, 20], 3, 2, 59, "Test 2: [-1,10,20] * 2 = 59"),
        ([-1, -2, -3], 3, 3, -1, "Test 3: [-1,-2,-3] * 3 = -1"),
    ]
    
    passed = 0
    failed = 0
    
    for a, n, k, expected, description in test_cases:
        dut._log.info(f"Running: {description}")
        
        try:
            result = await run_test(dut, a, n, k, expected)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            dut._log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            dut._log.error(f"  FAIL: {e}")
            failed += 1
            
        # Reset between tests
        await reset_dut(dut)
    
    dut._log.info(f"{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")