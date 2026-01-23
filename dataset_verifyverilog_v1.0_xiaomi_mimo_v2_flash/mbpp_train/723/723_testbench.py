import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
ARRAY_SIZE = 8
RESULT_WIDTH = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 100

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

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut):
    for _ in range(MAX_CYCLES):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return
    raise TestFailure(f"Timeout after {MAX_CYCLES} cycles")

async def write_signed_array(dut, name, values):
    arr = getattr(dut, name)
    for i, val in enumerate(values):
        arr[i].value = from_signed(val, DATA_WIDTH)

@cocotb.test(timeout_time=100, timeout_unit="ms")
async def test_count_same_pair(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        ([1, 2, 3, 4, 5, 6, 7, 8], [2, 2, 3, 1, 2, 6, 7, 9], 3, "Test 1: 3 matches"),
        ([0, 1, 2, -1, -5, 6, 0, -3], [2, 1, 2, -1, -5, 6, 4, -3], 6, "Test 2: 6 matches"),
        ([2, 4, -6, -9, 11, -12, 14, -5], [2, 1, 2, -1, -5, 6, 4, -3], 1, "Test 3: 1 match"),
        ([0, 1, 1, 2, 0, 0, 0, 0], [0, 1, 2, 2, 0, 0, 0, 0], 6, "Test 4: 6 matches"),
        ([0]*8, [0]*8, 8, "All zeros"),
        ([1, 2, 3, 4, 5, 6, 7, 8], [8, 7, 6, 5, 4, 3, 2, 1], 0, "No matches")
    ]
    
    passed = 0
    for arr1, arr2, expected, desc in test_cases:
        cocotb.log.info(f"Running: {desc}")
        await write_signed_array(dut, 'arr1', arr1)
        await write_signed_array(dut, 'arr2', arr2)
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        await wait_for_done(dut)
        
        if not is_value_defined(dut.result.value):
            raise TestFailure("Result undefined")
        
        raw = int(dut.result.value)
        actual = to_signed(raw, RESULT_WIDTH)
        
        if actual != expected:
            raise TestFailure(f"{desc}: expected {expected}, got {actual}")
        
        cocotb.log.info(f"  PASS: {actual}")
        passed += 1
    
    cocotb.log.info(f"All {passed}/{len(test_cases)} tests passed")