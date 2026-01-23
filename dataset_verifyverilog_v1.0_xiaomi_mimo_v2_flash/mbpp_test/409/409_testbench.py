import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
RESULT_WIDTH = 16
ARRAY_SIZE = 4
CLK_PERIOD_NS = 10
MAX_CYCLES = 100

def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_min_product_tuple(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        ([(2, 7), (2, 6), (1, 8), (4, 9)], 8, "Test 1: min 1*8=8"),
        ([(10, 20), (15, 2), (5, 10)], 30, "Test 2: min 15*2=30"),
        ([(11, 44), (10, 15), (20, 5), (12, 9)], 100, "Test 3: min 20*5=100"),
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, (pairs, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {test_idx + 1}: {description}")
        try:
            num_pairs = len(pairs)
            if num_pairs > ARRAY_SIZE:
                num_pairs = ARRAY_SIZE
                pairs = pairs[:ARRAY_SIZE]
            
            for i, (x, y) in enumerate(pairs):
                x_clamped = clamp_to_width(x, DATA_WIDTH)
                y_clamped = clamp_to_width(y, DATA_WIDTH)
                getattr(dut, f'arr_{i}_x').value = x_clamped
                getattr(dut, f'arr_{i}_y').value = y_clamped
            
            for i in range(len(pairs), ARRAY_SIZE):
                getattr(dut, f'arr_{i}_x').value = 255
                getattr(dut, f'arr_{i}_y').value = 255
            
            dut.num_pairs.value = num_pairs
            await start_computation(dut)
            await wait_for_done(dut)
            
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
    
    cocotb.log.info(f"\n{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")