import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH, ARRAY_SIZE, CLK_NS, MAX_CYCLES = 16, 1, 10, 1000

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_math_problem(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')
    
    # Test cases: (m, n, p, q, expected_result, description)
    test_cases = [
        (5, 2, 8, 4, 20512, "5 2 8 4 -> 20512"),
        (2, 1, 11, 4, 0, "2 1 11 4 -> IMPOSSIBLE")
    ]
    
    passed = failed = 0
    for i, (m, n, p, q, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Set inputs
            if has_signal(dut, 'm'): dut.m.value = clamp_to_width(m, 4)
            if has_signal(dut, 'n'): dut.n.value = clamp_to_width(n, 4)
            if has_signal(dut, 'p'): dut.p.value = clamp_to_width(p, 8)
            if has_signal(dut, 'q'): dut.q.value = clamp_to_width(q, 8)
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(200, units='ns')
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            # For IMPOSSIBLE cases, we expect 0 (or check separate IMPOSSIBLE signal)
            if result != expected:
                if expected == 0:
                    # Check if we have IMPOSSIBLE indicator
                    if has_signal(dut, 'impossible'):
                        imp = int(dut.impossible.value)
                        if imp == 1:
                            passed += 1
                            continue
                raise TestFailure(f"Expected {expected}, got {result}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")