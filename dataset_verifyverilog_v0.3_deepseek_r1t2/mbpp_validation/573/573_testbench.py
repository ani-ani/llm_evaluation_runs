import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
ARRAY_SIZE = 8
RESULT_WIDTH = 32
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

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
    return min(max_val, max(0, value))

async def write_array(dut, values, element_width):
    for i in range(8):
        port_name = f"arr_{i}"
        if has_signal(dut, port_name):
            if i < len(values):
                getattr(dut, port_name).value = clamp_to_width(values[i], element_width)
            else:
                getattr(dut, port_name).value = 0

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
async def test_unique_product(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        ([10, 20, 30, 40, 20, 50, 60, 40], 720000000, "Test 1"),
        ([1, 2, 3, 1], 6, "Test 2"),
        ([7, 8, 9, 0, 1, 1], 0, "Test 3"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (inputs, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            await write_array(dut, inputs, DATA_WIDTH)
            dut.len.value = len(inputs)
            
            await start_computation(dut)
            await wait_for_done(dut)
            
            if not is_value_defined(dut.result.value):
                raise TestFailure(f"Result undefined")
            
            result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        await RisingEdge(dut.clk)
    
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")