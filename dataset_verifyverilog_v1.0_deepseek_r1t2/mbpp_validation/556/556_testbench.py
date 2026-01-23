import cocotb
from cocotb.triggers import Timer, RisingEdge
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

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut):
    for cycle in range(MAX_CYCLES):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {MAX_CYCLES} cycles")

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def write_array_fixed(dut, values, len_val):
    for i in range(ARRAY_SIZE):
        if i < len(values):
            port_name = f'arr_{i}'
            if has_signal(dut, port_name):
                getattr(dut, port_name).value = clamp_to_width(values[i], DATA_WIDTH)
        else:
            port_name = f'arr_{i}'
            if has_signal(dut, port_name):
                getattr(dut, port_name).value = 0
    if has_signal(dut, 'len'):
        dut.len.value = clamp_to_width(len_val, 4)

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_find_Odd_Pair(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        ([5, 4, 7, 2, 1], 6, "Test 1: [5,4,7,2,1] -> 6"),
        ([7, 2, 8, 1, 0, 5, 11], 12, "Test 2: [7,2,8,1,0,5,11] -> 12"),
        ([1, 2, 3], 2, "Test 3: [1,2,3] -> 2"),
        ([1, 3, 5, 7], 0, "Test 4: All odd -> 0"),
        ([2, 4, 6, 8], 0, "Test 5: All even -> 0"),
        ([1, 2], 1, "Test 6: [1,2] -> 1"),
        ([0, 0, 0], 0, "Test 7: [0,0,0] -> 0"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (values, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {description}")
        try:
            await write_array_fixed(dut, values, len(values))
            await start_computation(dut)
            await wait_for_done(dut)
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined")
            
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"SUMMARY: {passed}/{passed+failed} tests passed")
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")