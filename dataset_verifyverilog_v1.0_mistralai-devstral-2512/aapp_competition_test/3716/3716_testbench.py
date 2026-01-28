import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

DATA_WIDTH = 16
RESULT_WIDTH = 32
CLK_NS = 10
MAX_CYCLES = 400000

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def compute_lcm_py(a, b, c):
    def gcd(x, y):
        while y:
            x, y = y, x % y
        return x
    lcm_ab = (a * b) // gcd(a, b)
    return (lcm_ab * c) // gcd(lcm_ab, c)

async def expected_lcm(n):
    if n <= 2:
        return n
    if n == 3:
        return 6
    
    # Search limited to 64 elements for hardware feasibility
    search_start = max(1, n - 63)
    max_lcm = 0
    
    for i in range(n, search_start - 1, -1):
        for j in range(i, search_start - 1, -1):
            for k in range(j, search_start - 1, -1):
                lcm_val = await compute_lcm_py(i, j, k)
                if lcm_val > max_lcm:
                    max_lcm = lcm_val
    return max_lcm

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_max_lcm(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases that fit within 16-bit n
    test_cases = [
        (9, 504, "n=9"),
        (7, 210, "n=7"),
        (1, 1, "n=1"),
        (5, 60, "n=5"),
        (6, 60, "n=6"),
        (8, 280, "n=8"),
        (3, 6, "n=3"),
        (4, 12, "n=4"),
        (20, 6460, "n=20"),
        (30, 21924, "n=30"),
        (12, 990, "n=12"),
        (18, 4080, "n=18"),
        (21, 7980, "n=21"),
        (33, 32736, "n=33"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n_val, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} (n={n_val})")
        try:
            if not is_seq:
                dut.n.value = n_val
                await Timer(100, units='ns')
            else:
                # Reset again for clean start
                dut.rst_n.value = 0
                await RisingEdge(dut.clk)
                dut.rst_n.value = 1
                await RisingEdge(dut.clk)
                
                dut.n.value = clamp_to_width(n_val, DATA_WIDTH)
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result}")
            
            cocotb.log.info(f"  PASS: result={result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    else:
        cocotb.log.info(f"All {passed} tests passed")