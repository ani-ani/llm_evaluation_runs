import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 32
CLK_PERIOD_NS = 10
FRAC_BITS = 16

def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

def float_to_fixed(f):
    return int(f * (1 << FRAC_BITS))

def fixed_to_float(fixed):
    return fixed / (1 << FRAC_BITS)

async def reset_dut(dut):
    dut.rst_n.value = 0
    if hasattr(dut, 'start'):
        dut.start.value = 0
    if hasattr(dut, 'p_valid'):
        dut.p_valid.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def send_probability(dut, p_value):
    dut.p_in.value = clamp_to_width(float_to_fixed(p_value), DATA_WIDTH)
    dut.p_valid.value = 1
    await RisingEdge(dut.clk)
    dut.p_valid.value = 0

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_game(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        (1, 1, [0.5], 0.5, "1 vs 1, 0.5"),
        (3, 2, [1.0, 0.0, 1.0, 0.0], 1.0, "3 vs 2, alternating"),
        (3, 2, [0.0, 0.0, 0.0, 0.0], 0.0, "3 vs 2, all zeros"),
        (2, 2, [0.5, 0.5, 0.5], 0.5, "2 vs 2, uniform 0.5"),
        (1, 1, [0.0], 0.0, "1 vs 1, zero"),
        (1, 1, [1.0], 1.0, "1 vs 1, one"),
    ]
    
    passed = 0
    for i, (N, M, probs, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            await reset_dut(dut)
            dut.N.value = N
            dut.M.value = M
            await start_computation(dut)
            for p in probs:
                await send_probability(dut, p)
            await wait_for_done(dut)
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = fixed_to_float(int(dut.result.value))
            if abs(result - expected) > 1e-6:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: {result:.6f}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
    
    cocotb.log.info(f"Results: {passed}/{len(test_cases)} passed")
    if passed != len(test_cases):
        raise TestFailure(f"{len(test_cases)-passed} tests failed")