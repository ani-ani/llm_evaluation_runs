import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
ARRAY_SIZE = 8
RESULT_WIDTH = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000
FRAC_BITS = 8

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

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    if value < 0:
        min_val = -(1 << (bits - 1))
        max_val = (1 << (bits - 1)) - 1
        clamped = max(min_val, min(max_val, value))
        return from_signed(clamped, bits)
    return min(max_val, max(0, value))

def float_to_q88(f):
    fixed = int(f * (1 << FRAC_BITS))
    return clamp_to_width(fixed, DATA_WIDTH)

def q88_to_float(fixed):
    signed_val = to_signed(fixed, DATA_WIDTH)
    return signed_val / (1 << FRAC_BITS)

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

async def write_array(dut, values, element_width):
    for i in range(8):
        if i < len(values):
            port_name = f'arr_{i}'
            if has_signal(dut, port_name):
                getattr(dut, port_name).value = clamp_to_width(values[i], element_width)
        else:
            port_name = f'arr_{i}'
            if has_signal(dut, port_name):
                getattr(dut, port_name).value = 0

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_second_smallest(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        ([float_to_q88(1), float_to_q88(2), float_to_q88(-8), float_to_q88(-2), float_to_q88(0), float_to_q88(-2)], float_to_q88(-2), "Test 1: [1,2,-8,-2,0,-2] -> -2"),
        ([float_to_q88(1), float_to_q88(1), float_to_q88(-0.5), float_to_q88(0), float_to_q88(2), float_to_q88(-2), float_to_q88(-2)], float_to_q88(-0.5), "Test 2: [1,1,-0.5,0,2,-2,-2] -> -0.5"),
        ([float_to_q88(2), float_to_q88(2)], 0xFFFF, "Test 3: [2,2] -> None"),
        ([float_to_q88(2), float_to_q88(2), float_to_q88(2)], 0xFFFF, "Test 4: [2,2,2] -> None"),
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
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            if expected == 0xFFFF:
                if result != 0xFFFF:
                    raise TestFailure(f"Expected None (0xFFFF), got {result}")
            else:
                expected_float = q88_to_float(expected)
                result_float = q88_to_float(result)
                if abs(result_float - expected_float) > 0.01:
                    raise TestFailure(f"Expected {expected_float:.3f}, got {result_float:.3f}")
            
            cocotb.log.info(f"  PASS: result = {result} ({q88_to_float(result):.3f})")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
