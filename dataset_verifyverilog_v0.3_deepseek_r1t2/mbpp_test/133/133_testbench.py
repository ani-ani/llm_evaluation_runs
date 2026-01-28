import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 8
RESULT_WIDTH = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 100
ARRAY_SIZE = 8

# Helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

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

async def wait_for_done(dut):
    for _ in range(MAX_CYCLES):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return
    raise TestFailure("Timeout waiting for done")

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def write_signed_array(dut, values):
    for i, val in enumerate(values):
        unsigned_val = from_signed(val, DATA_WIDTH)
        dut.arr[i].value = unsigned_val

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_sum_negative_numbers(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        ([2, 4, -6, -9, 11, -12, 14, -5], -32, "Test 1"),
        ([10, 15, -14, 13, -18, 12, -20, 0], -52, "Test 2"),
        ([19, -65, 57, 39, 152, -639, 121, 44], -894, "Test 3 truncated"),
        ([-1, -2, -3, 0, 0, 0, 0, 0], -6, "All negative"),
        ([1, 2, 3, 4, 5, 6, 7, 8], 0, "All positive"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_list, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        try:
            await write_signed_array(dut, input_list)
            dut.len.value = len(input_list)
            await start_computation(dut)
            await wait_for_done(dut)
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            raw_result = int(dut.result.value)
            result = to_signed(raw_result, RESULT_WIDTH)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: {result}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    cocotb.log.info(f"Results: {passed}/{passed+failed} passed")
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")