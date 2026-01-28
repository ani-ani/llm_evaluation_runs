import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants based on scaled requirements
DATA_WIDTH = 10  # Coin counts up to 1000
N_MAX = 7        # bits for n (up to 100)
CLK_NS = 10
MAX_CYCLES = 100
RESULT_WIDTH = 16

# Helpers from rules
def is_value_defined(v):
    try:
        int(v); return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try:
        getattr(dut, name); return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# Compute expected result in Python (same algorithm as spec)
def compute_expected(n, coins):
    if n == 1 or n % 2 == 0:
        return 0xFFFF  # -1
    a = coins[:n]  # 0-indexed
    moves = 0
    # Process from last odd index down to 3
    for i in range(n-1, 1, -2):  # i is odd (1-based), 0-indexed i and i-1
        child_max = max(a[i], a[i-1])
        moves += child_max
        parent_idx = (i-1) // 2
        a[parent_idx] = max(0, a[parent_idx] - child_max)
        a[i] = 0
        a[i-1] = 0
    moves += a[0]  # root coins
    return moves

# Write n coins into dut.a_i array (dut.a_1 to dut.a_n)
async def write_coins(dut, n, coins):
    for i in range(1, n+1):
        if has_signal(dut, f'a_{i}'):
            val = coins[i-1] if i-1 < len(coins) else 0
            getattr(dut, f'a_{i}').value = clamp_to_width(val, DATA_WIDTH)
        else:
            raise TestFailure(f"Signal a_{i} not found")

@cocotb.test(timeout_time=10, timeout_unit='ms')
async def test_pirate_chests(dut):
    # Setup clock and reset
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (n, coins list)
    test_cases = [
        (1, [1]),                          # n=1, expected -1
        (3, [1, 2, 3]),                    # Example 2
        (5, [2, 1, 2, 2, 1]),              # Odd n, valid
        (2, [707, 629]),                   # Even n, expected -1
        (7, [760, 154, 34, 77, 792, 950, 159]),  # Odd n
    ]
    
    passed = 0
    failed = 0
    
    for n, coins in test_cases:
        cocotb.log.info(f"Testing n={n}, coins={coins}")
        try:
            # Write inputs
            dut.n.value = n
            await write_coins(dut, n, coins)
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            result = int(dut.result.value)
            expected = compute_expected(n, coins)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
            
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
