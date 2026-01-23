import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# CONFIGURATION
DATA_WIDTH = 8
ARRAY_SIZE = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 100

# HELPER FUNCTIONS

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

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def write_array(dut, values, element_width):
    # Try array indexing first
    try:
        arr = getattr(dut, 'arr')
        for i in range(ARRAY_SIZE):
            if i < len(values):
                arr[i].value = clamp_to_width(values[i], element_width)
            else:
                arr[i].value = 0
        return
    except (AttributeError, TypeError):
        pass
    
    # Try individual ports
    for i in range(ARRAY_SIZE):
        port_name = f'arr_{i}'
        if has_signal(dut, port_name):
            val = values[i] if i < len(values) else 0
            getattr(dut, port_name).value = clamp_to_width(val, element_width)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_check_consecutive(dut):
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: inputs (8 numbers), expected result, description
    test_cases = [
        ([1, 2, 3, 4, 5, 6, 7, 8], 1, "1-8 consecutive"),
        ([1, 2, 3, 5, 6, 7, 8, 4], 1, "1-8 shuffled"),
        ([1, 2, 3, 4, 5, 6, 7, 9], 0, "Missing 8"),
        ([1, 2, 3, 4, 5, 6, 7, 7], 0, "Duplicate 7"),
        ([0, 1, 2, 3, 4, 5, 6, 7], 1, "0-7 consecutive"),
        ([1, 3, 4, 5, 6, 7, 8, 9], 0, "Missing 2"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (inputs, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        try:
            await write_array(dut, inputs, DATA_WIDTH)
            await RisingEdge(dut.clk)
            await start_computation(dut)
            await wait_for_done(dut)
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    cocotb.log.info(f"Results: {passed}/{passed+failed} passed")
    if failed > 0:
        raise TestFailure(f"{failed} failed")