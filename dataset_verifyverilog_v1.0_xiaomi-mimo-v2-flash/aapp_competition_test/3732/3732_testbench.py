import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helper functions
DATA_WIDTH = 16
FIXED_POINT_SHIFT = 8
MAX_ITER = 1024

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def to_signed(val, bits):
    val = int(val)
    if val >= (1 << (bits-1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    val = int(val)
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, int(v)))

# Fixed point conversion
def to_fixed(val, shift=FIXED_POINT_SHIFT):
    # Scale large python integers to fit 16-bit fixed point for simulation
    # We map range roughly -327 to +327. 
    # For testing, we simply truncate/round to fit 16 bits assuming input was pre-scaled.
    return int(val) & 0xFFFF

def float_to_fixed(f, frac=FIXED_POINT_SHIFT):
    return int(f * (1 << frac))

def fixed_to_float(v, frac=FIXED_POINT_SHIFT):
    if v >= (1 << 15):
        v -= (1 << 16)
    return v / (1 << frac)

# Reference Logic (Python)
def solve_logic(x, y, m):
    if x > y: x, y = y, x
    if y >= m: return 0
    if y <= 0: return -1
    ans = 0
    if x < 0:
        # Calculate steps to make x >= 0
        # ceil(|x| / y)
        steps = (-x + y - 1) // y
        ans += steps
        x += steps * y
    while y < m:
        x, y = y, x + y
        ans += 1
        if ans > 10000: # Safety for testbench
            return -1 # Treat as failure or timeout
    return ans

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_m_perfect(dut):
    # Setup Clock
    if has_signal(dut, 'clk'):
        clock = Clock(dut.clk, 10, units="ns")
        cocotb.start_soon(clock.start())
    
    # Setup Reset
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    await Timer(50, units="ns")
    if has_signal(dut, 'clk'): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    if has_signal(dut, 'clk'): await RisingEdge(dut.clk)

    # Test Cases
    # We use scaled inputs. For exhaustive testing, we rely on the reference logic.
    test_vectors = [
        (1, 2, 5),       # Ex 1
        (-1, 4, 15),     # Ex 2
        (0, -1, 5),      # Ex 3 (Impossible)
        (0, 1, 8),       # Ex 4
        (10, 10, 20),    # 0 ops
        (5, 1, 100),     # Standard growth
        (-10, 1, 5),     # Negative start
        (0, 0, 1),       # Impossible
        (-1, -1, -2),    # Both negative, m negative (0 ops if satisfied)
        (-1, -1, 0),     # Both negative, m larger
    ]

    # We need to scale these inputs to fit the 16-bit fixed point interface.
    # The prompt specifies scaling. We will simply pass them as is if they fit in 16 bits.
    # Large values from the problem statement (10^18) will be truncated or mapped.
    # For this benchmark, we focus on the logic correctness with small ints.
    
    passed = 0
    failed = 0

    for x, y, m in test_vectors:
        # Skip if values out of 16-bit range for this specific test setup
        if not (-32768 <= x <= 32767 and -32768 <= y <= 32767 and -32768 <= m <= 32767):
            continue
            
        cocotb.log.info(f"Testing x={x}, y={y}, m={m}")
        
        # Expected result
        expected = solve_logic(x, y, m)
        
        # Apply inputs
        dut.x_in.value = from_signed(x, DATA_WIDTH)
        dut.y_in.value = from_signed(y, DATA_WIDTH)
        dut.m_in.value = from_signed(m, DATA_WIDTH)
        
        # Start pulse
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        done_found = False
        for _ in range(MAX_ITER + 100):
            await RisingEdge(dut.clk)
            if has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done_found = True
                break
        
        if not done_found:
            cocotb.log.error(f"Timeout for x={x}, y={y}, m={m}")
            failed += 1
            continue
            
        # Read result
        if not has_signal(dut, 'result'):
            cocotb.log.error("Result signal missing")
            failed += 1
            continue
            
        res_raw = int(dut.result.value)
        res_val = to_signed(res_raw, 32)
        
        if res_val == expected:
            cocotb.log.info(f"PASS: Got {res_val}")
            passed += 1
        else:
            cocotb.log.error(f"FAIL: Expected {expected}, Got {res_val}")
            failed += 1

    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
