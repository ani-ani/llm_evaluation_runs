import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

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
    return min((1 << bits) - 1, max(0, v))

# Constants
DATA_WIDTH = 3
MAX_N = 16
K_MAX = 5
COLOR_MAX = 8
CLK_NS = 10
MAX_CYCLES = 1000

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_sequence(dut, colors, K):
    """Write sequence to input arrays"""
    # Write colors to arr_colors array
    if hasattr(dut, 'arr_colors'):
        for i in range(MAX_N):
            if i < len(colors):
                dut.arr_colors[i].value = clamp_to_width(colors[i], DATA_WIDTH)
            else:
                dut.arr_colors[i].value = 0
    
    # Write length and K requirement
    if hasattr(dut, 'arr_len'):
        dut.arr_len.value = clamp_to_width(len(colors), 4)
    
    if hasattr(dut, 'K_req'):
        dut.K_req.value = clamp_to_width(K, 3)

# Expected Python reference implementation
def min_insertions_reference(colors, K):
    """Reference implementation in Python"""
    n = len(colors)
    if n == 0:
        return 0
    
    # dp[i][j] = min insertions to clear colors[i..j]
    dp = [[0] * n for _ in range(n)]
    
    # Fill for increasing lengths
    for length in range(1, n + 1):
        for i in range(n - length + 1):
            j = i + length - 1
            
            # Base case: need K identical to vanish
            needed = K - length
            if needed <= 0:
                # Already have K or more, but need same color
                # For simplicity, consider inserting to make all same color
                dp[i][j] = 0 if length >= K else needed
            else:
                dp[i][j] = needed
            
            # Try splits to reduce insertions
            if length >= 2:
                for m in range(i, j):
                    dp[i][j] = min(dp[i][j], dp[i][m] + dp[m+1][j])
    
    return dp[0][n-1]

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_marble_vanishing(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational, just apply inputs
        await Timer(100, units='ns')
    
    # Test cases based on problem examples
    test_cases = [
        ([1, 1], 5, 3, "Sample 1: N=2, K=5"),
        ([2, 2, 3, 2, 2], 3, 2, "Sample 2: N=5, K=3"),
        ([3, 3, 3, 3, 2, 3, 1, 1, 1, 3], 4, 4, "Sample 3: N=10, K=4"),
        ([1], 3, 2, "Single marble, need 2 more"),
        ([1, 1, 1], 3, 0, "Exactly K, no insertions"),
        ([1, 2, 1], 3, 4, "Mixed colors, need insertions"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (colors, K, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        
        # Compute reference result
        ref_result = min_insertions_reference(colors, K)
        if ref_result != expected:
            cocotb.log.warning(f"Reference mismatch: expected {expected}, got {ref_result}")
        
        try:
            # Write inputs
            if is_seq:
                await write_sequence(dut, colors, K)
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await write_sequence(dut, colors, K)
                await Timer(100, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"PASS: {desc} => {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
        
        # Reset between tests
        if is_seq and i < len(test_cases) - 1:
            await reset_dut(dut)
    
    # Summary
    cocotb.log.info(f"\nResults: {passed} passed, {failed} failed")
    if failed:
        raise TestFailure(f"{failed} test(s) failed")