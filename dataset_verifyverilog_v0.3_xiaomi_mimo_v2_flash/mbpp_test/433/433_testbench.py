import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
ARRAY_SIZE = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 100

def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def write_array(dut, array_name, values, element_width):
    for i, val in enumerate(values):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(val, element_width)

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
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_check_greater(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        ([1, 2, 3, 4, 5], 4, False, "number=4, arr max=5"),
        ([2, 3, 4, 5, 6], 8, True, "number=8, arr max=6"),
        ([9, 7, 4, 8, 6, 1], 11, True, "number=11, arr max=9"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (arr_vals, number_val, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        try:
            padded_arr = arr_vals + [0] * (8 - len(arr_vals))
            await write_array(dut, 'arr', padded_arr, DATA_WIDTH)
            dut.number.value = clamp_to_width(number_val, DATA_WIDTH)
            await Timer(10, units='ns')
            await start_computation(dut)
            await wait_for_done(dut)
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined")
            
            result = bool(int(dut.result.value))
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_edge_cases(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    edge_cases = [
        ([255, 255, 255, 255, 255, 255, 255, 255], 255, False, "All 255, number=255"),
        ([254, 254, 254, 254, 254, 254, 254, 254], 255, True, "All 254, number=255"),
        ([0, 0, 0, 0, 0, 0, 0, 0], 1, True, "All zeros, number=1"),
        ([1, 1, 1, 1, 1, 1, 1, 1], 0, False, "All ones, number=0"),
        ([100, 50, 75, 200, 30, 150, 25, 10], 201, True, "Max at middle, greater"),
        ([100, 50, 75, 200, 30, 150, 25, 10], 199, False, "Max at middle, less"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (arr_vals, number_val, expected, description) in enumerate(edge_cases):
        cocotb.log.info(f"Edge test {i+1}: {description}")
        try:
            await write_array(dut, 'arr', arr_vals, DATA_WIDTH)
            dut.number.value = clamp_to_width(number_val, DATA_WIDTH)
            await Timer(10, units='ns')
            await start_computation(dut)
            await wait_for_done(dut)
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined")
            
            result = bool(int(dut.result.value))
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Edge Results: {passed}/{passed+failed} tests passed")
    if failed > 0:
        raise TestFailure(f"{failed} edge tests failed")