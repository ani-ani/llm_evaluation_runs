import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 8
ARRAY_SIZE = 8
RESULT_WIDTH = 16
FP_FRAC_BITS = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 5000

# Helper functions
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

async def write_weights(dut, weights, element_width=DATA_WIDTH):
    try:
        for i in range(len(weights)):
            dut.weights[i].value = clamp_to_width(weights[i], element_width)
        return
    except (AttributeError, TypeError):
        pass
    
    for i in range(len(weights)):
        port_name = f"weights_{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(weights[i], element_width)
        else:
            raise TestFailure(f"Cannot find array port: {port_name}")

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

def float_to_fixed(f, frac_bits=FP_FRAC_BITS):
    return int(f * (1 << frac_bits))

def fixed_to_float(fixed, frac_bits=FP_FRAC_BITS):
    return fixed / (1 << frac_bits)

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_figurine_4pack(dut):
    if not has_signal(dut, 'clk'):
        raise TestFailure("DUT missing 'clk' signal")
    if not has_signal(dut, 'rst_n'):
        raise TestFailure("DUT missing 'rst_n' signal")
    if not has_signal(dut, 'start'):
        raise TestFailure("DUT missing 'start' signal")
    if not has_signal(dut, 'done'):
        raise TestFailure("DUT missing 'done' signal")
    
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        ([1, 2, 4, 7], 28, 4, 21, 14.0, "Case 1: [1,2,4,7]"),
        ([2, 4, 5], 20, 8, 12, 44/3, "Case 2: [2,4,5]"),
        ([10, 20], 80, 40, 5, 60.0, "Case 3: [10,20]"),
        ([5], 20, 20, 1, 20.0, "Case 4: [5]"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (weights, exp_max, exp_min, exp_distinct, exp_expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            await write_weights(dut, weights)
            await start_computation(dut)
            await wait_for_done(dut)
            
            max_val = safe_int(dut.max_weight.value)
            min_val = safe_int(dut.min_weight.value)
            distinct_val = safe_int(dut.num_distinct.value)
            
            if not is_value_defined(dut.expected_weight.value):
                raise TestFailure("expected_weight undefined")
            expected_fp = int(dut.expected_weight.value)
            expected_float = fixed_to_float(expected_fp)
            
            if max_val != exp_max:
                raise TestFailure(f"max: expected {exp_max}, got {max_val}")
            if min_val != exp_min:
                raise TestFailure(f"min: expected {exp_min}, got {min_val}")
            if distinct_val != exp_distinct:
                raise TestFailure(f"distinct: expected {exp_distinct}, got {distinct_val}")
            if abs(expected_float - exp_expected) > 0.0001:
                raise TestFailure(f"expected: {exp_expected:.8f} vs {expected_float:.8f}")
            
            cocotb.log.info(f"  PASS: max={max_val}, min={min_val}, distinct={distinct_val}, expected={expected_float:.8f}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")