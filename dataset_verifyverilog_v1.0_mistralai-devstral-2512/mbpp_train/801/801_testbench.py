import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 8
CLK_NS = 10
MAX_CYCLES = 100

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

def calculate_expected(x, y, z):
    result_set = set([x, y, z])
    if len(result_set) == 3:
        return 0
    else:
        return 4 - len(result_set)

async def test_single_case(dut, x, y, z, expected):
    dut.x.value = from_signed(x, DATA_WIDTH)
    dut.y.value = from_signed(y, DATA_WIDTH)
    dut.z.value = from_signed(z, DATA_WIDTH)
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result signal is undefined")
    
    result = int(dut.result.value)
    
    if result != expected:
        raise TestFailure(f"For inputs x={x}, y={y}, z={z}, expected {expected}, got {result}")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_three_equal(dut):
    # Verify essential signals exist
    if not has_signal(dut, 'clk'):
        raise TestFailure("Missing required signal: clk")
    if not has_signal(dut, 'x') or not has_signal(dut, 'y') or not has_signal(dut, 'z'):
        raise TestFailure("Missing required input signals")
    if not has_signal(dut, 'result') or not has_signal(dut, 'done'):
        raise TestFailure("Missing required output signals")
    
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases from problem
    cocotb.log.info("Test 1: All equal (1,1,1) -> expected 3")
    await test_single_case(dut, 1, 1, 1, 3)
    
    cocotb.log.info("Test 2: All different (-1,-2,-3) -> expected 0")
    await test_single_case(dut, -1, -2, -3, 0)
    
    cocotb.log.info("Test 3: Two equal (1,2,2) -> expected 2")
    await test_single_case(dut, 1, 2, 2, 2)
    
    # Additional edge cases
    cocotb.log.info("Test 4: First two equal (5,5,3) -> expected 2")
    await test_single_case(dut, 5, 5, 3, 2)
    
    cocotb.log.info("Test 5: First and last equal (7,8,7) -> expected 2")
    await test_single_case(dut, 7, 8, 7, 2)
    
    # Random tests
    random.seed(42)
    for i in range(10):
        x = random.randint(-128, 127)
        y = random.randint(-128, 127)
        z = random.randint(-128, 127)
        expected = calculate_expected(x, y, z)
        cocotb.log.info(f"Random test {i+1}: x={x}, y={y}, z={z}, expected={expected}")
        await test_single_case(dut, x, y, z, expected)
    
    cocotb.log.info("All tests passed!")