import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    if v < 0: return 0 # Unsigned clamp
    return min((1 << bits) - 1, v)

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=15000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=30, timeout_unit="s")
async def test_circular_traversal(dut):
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')

    # Test cases: (n, k, a, b, expected_min, expected_max)
    # Scaled down for hardware constraints (n<=64, k<=1024)
    test_cases = [
        (2, 3, 1, 1, 1, 6),
        (3, 2, 0, 0, 1, 3),
        (1, 10, 5, 3, 5, 5),
        (3, 3, 1, 0, 9, 9),
        (4, 3, 1, 1, 1, 12),
        (5, 5, 2, 2, 1, 25),
        (6, 3, 1, 1, 1, 18),
        (3, 10, 1, 3, 5, 15),
        (2, 1, 0, 0, 1, 2),
        (1, 100, 0, 0, 1, 1)
    ]

    passed = 0
    failed = 0

    for i, (n_val, k_val, a_val, b_val, exp_min, exp_max) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: n={n_val}, k={k_val}, a={a_val}, b={b_val}")
        
        try:
            if has_signal(dut, 'clk'):
                await reset_dut(dut)
            
            # Write inputs
            dut.n.value = clamp_to_width(n_val, 6)
            dut.k.value = clamp_to_width(k_val, 10)
            dut.a.value = clamp_to_width(a_val, 9)
            dut.b.value = clamp_to_width(b_val, 9)
            
            # Start
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            # Read outputs
            res_min = int(dut.result_min.value)
            res_max = int(dut.result_max.value)
            
            if res_min != exp_min or res_max != exp_max:
                raise TestFailure(f"Expected ({exp_min}, {exp_max}), got ({res_min}, {res_max})")
            
            passed += 1
            cocotb.log.info(f"PASS: Result {res_min}, {res_max}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1

    if failed:
        raise TestFailure(f"{failed} tests failed")
