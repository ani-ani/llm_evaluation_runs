import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH, CLK_NS, MAX_CYCLES = 8, 10, 1000

def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def compute_fibfib(dut, n_val):
    dut.n.value = clamp_to_width(n_val, DATA_WIDTH)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await wait_for_done(dut)
    return safe_int(dut.result.value)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_fibfib(dut):
    if not has_signal(dut, 'clk'):
        raise TestFailure("Module must have 'clk' signal")
    
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        (1, 0, "n=1"),
        (2, 1, "n=2"),
        (5, 4, "n=5"),
        (8, 24, "n=8"),
        (10, 81, "n=10"),
        (12, 274, "n=12"),
        (14, 927, "n=14")
    ]
    
    passed = failed = 0
    
    for i, (n_val, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} (n={n_val}, expected={expected})")
        try:
            result = await compute_fibfib(dut, n_val)
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"PASS: {desc} => {result}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {desc} - {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} out of {len(test_cases)} tests failed")
    
    cocotb.log.info(f"\nAll {passed} tests passed!")