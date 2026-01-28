import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

MOD = 10**9 + 7
DATA_WIDTH = 32
ARRAY_SIZE = 20
CLK_NS = 10
MAX_CYCLES = 1000

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
    return min((1 << bits) - 1, max(0, v))

def mod_pow2(exp, mod=MOD):
    return pow(2, exp, mod)

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

def solve_py(coords, n):
    if n <= 1:
        return 0
    coords.sort()
    ans = 0
    for i in range(n - 1):
        diff = (coords[i+1] - coords[i]) % MOD
        left = (mod_pow2(i) - 1) % MOD
        right = (mod_pow2(n - 2 - i) - 1) % MOD
        contrib = (diff * left) % MOD
        contrib = (contrib * right) % MOD
        ans = (ans + contrib) % MOD
    return ans

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_leha_restaurant(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    test_cases = [
        ([4, 7], 2, 3),
        ([4, 3, 1], 3, 9),
        ([8, 11, 13, 19, 21, 34, 36, 44, 57, 58, 61, 63, 76, 78, 79, 81, 85, 86, 90, 95], 20, 83396599),
        ([78091781], 1, 0),
        ([1000000000, 1], 2, 999999999),
        ([999999998, 999999999, 999999992], 3, 21),
        ([10, 3, 6, 2, 1, 9, 8, 4, 5, 7], 10, 7181),
        ([9, 10, 7, 4, 5], 5, 114),
    ]
    
    passed = 0
    failed = 0
    
    for i, (coords, n, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: n={n}, coords={coords[:5]}...")
        try:
            # Write coordinates
            if has_signal(dut, 'coords'):
                # Array access
                for idx in range(ARRAY_SIZE):
                    val = coords[idx] if idx < n else 0
                    dut.coords[idx].value = clamp_to_width(val, DATA_WIDTH)
            elif hasattr(dut, 'coords_0'):
                for idx in range(ARRAY_SIZE):
                    val = coords[idx] if idx < n else 0
                    getattr(dut, f'coords_{idx}').value = clamp_to_width(val, DATA_WIDTH)
            
            # Write n
            if has_signal(dut, 'n'):
                dut.n.value = n
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")
