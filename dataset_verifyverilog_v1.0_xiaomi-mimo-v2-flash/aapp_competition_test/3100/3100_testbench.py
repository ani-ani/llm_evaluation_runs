import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

MOD = 10**9 + 7
MAX_INPUT = 20

# Helper functions
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

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

# Expected Python solution for reference
def solve_py(A, C, M):
    if A > MAX_INPUT or C > MAX_INPUT or M > MAX_INPUT or (A+C+M) > MAX_INPUT:
        return 0
    N = A + C + M
    if N == 0:
        return 0
    # dp[a][c][m][prev]
    dp = [[[[0]*3 for _ in range(M+1)] for _ in range(C+1)] for _ in range(A+1)]
    if A > 0:
        dp[1][0][0][0] = 1
    if C > 0:
        dp[0][1][0][1] = 1
    if M > 0:
        dp[0][0][1][2] = 1
    
    for a in range(A+1):
        for c in range(C+1):
            for m in range(M+1):
                for prev in range(3):
                    cur = dp[a][c][m][prev]
                    if cur == 0:
                        continue
                    # Try add apple
                    if prev != 0 and a < A:
                        dp[a+1][c][m][0] = (dp[a+1][c][m][0] + cur) % MOD
                    # Try add cherry
                    if prev != 1 and c < C:
                        dp[a][c+1][m][1] = (dp[a][c+1][m][1] + cur) % MOD
                    # Try add mango
                    if prev != 2 and m < M:
                        dp[a][c][m+1][2] = (dp[a][c][m+1][2] + cur) % MOD
    
    total = 0
    for prev in range(3):
        total = (total + dp[A][C][M][prev]) % MOD
    return total

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_fruit_arrangements(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk') and has_signal(dut, 'start') and has_signal(dut, 'done')
    
    if is_seq:
        # Setup clock and reset
        CLK_NS = 10
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        # Combinational - just wait for stability
        await Timer(100, units='ns')
    
    # Test cases
    test_cases = [
        (1, 2, 1, 6),
        (2, 2, 2, 30),
        (1, 1, 10, 0),  # Exceeds total constraint
        (1, 0, 1, 2),   # Simple case: 2 arrangements
        (3, 3, 3, 174), # Known value
        (5, 5, 5, 17160), # Known value
        (20, 0, 0, 0),  # Invalid: only one fruit type with count >1
        (0, 1, 0, 1),   # Single fruit
        (1, 1, 1, 6),   # All different
        (2, 1, 0, 2),   # A=2, C=1, M=0
    ]
    
    passed = 0
    failed = 0
    
    for i, (A, C, M, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: A={A}, C={C}, M={M}")
        
        # Set inputs
        if has_signal(dut, 'A_in'):
            dut.A_in.value = clamp_to_width(A, 5)
        if has_signal(dut, 'C_in'):
            dut.C_in.value = clamp_to_width(C, 5)
        if has_signal(dut, 'M_in'):
            dut.M_in.value = clamp_to_width(M, 5)
        
        if is_seq:
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            max_cycles = 2000
            done = False
            for _ in range(max_cycles):
                await RisingEdge(dut.clk)
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    done = True
                    break
            
            if not done:
                cocotb.log.error(f"Timeout waiting for done")
                failed += 1
                continue
        else:
            # Combinational - wait for propagation
            await Timer(100, units='ns')
        
        # Read results
        result_ok = True
        result_val = 0
        
        if has_signal(dut, 'result'):
            if is_value_defined(dut.result.value):
                result_val = int(dut.result.value)
            else:
                cocotb.log.error(f"Result undefined")
                result_ok = False
                failed += 1
                continue
        
        if has_signal(dut, 'error'):
            if is_value_defined(dut.error.value) and int(dut.error.value) == 1:
                cocotb.log.info(f"Error flag set (input invalid)")
                if expected == 0:
                    # Expected error
                    cocotb.log.info(f"PASS: Error correctly detected")
                    passed += 1
                else:
                    cocotb.log.error(f"FAIL: Unexpected error")
                    failed += 1
                continue
        
        if result_ok:
            if result_val == expected:
                cocotb.log.info(f"PASS: Got {result_val}")
                passed += 1
            else:
                cocotb.log.error(f"FAIL: Expected {expected}, got {result_val}")
                failed += 1
    
    cocotb.log.info(f"Summary: {passed} passed, {failed} failed")
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")