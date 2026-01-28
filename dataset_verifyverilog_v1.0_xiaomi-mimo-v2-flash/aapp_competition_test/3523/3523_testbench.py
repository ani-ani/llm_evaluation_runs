import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    if v < 0: return 0
    max_val = (1 << bits) - 1
    return min(v, max_val)

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

@cocotb.test(timeout_time=5000, timeout_unit='ms')
async def test_coin_change(dut):
    # Setup Clock
    dut._log.info("Starting testbench...")
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        # (P, N1, N5, N10, N25, Expected Result, Description)
        (13, 3, 2, 1, 1, 5, "Sample 1"),
        (13, 2, 2, 1, 1, 0, "Sample 2 Impossible"),
        (100, 20, 20, 20, 20, 4, "Quarter only"),
        (30, 100, 0, 0, 0, 30, "All 1s"),
        (15, 10, 2, 0, 0, 3, "1s and 5s"),
        (65535, 65535, 0, 0, 0, 65535, "Max P, Max 1s"),
    ]
    
    passed = 0
    failed = 0
    
    for P, N1, N5, N10, N25, exp_res, desc in test_cases:
        dut._log.info(f"Running test: {desc} (P={P}, N1={N1}...)")
        
        # Clamp inputs to 16-bit (if HDL clips them, we should too for comparison)
        P_in = clamp_to_width(P, 16)
        N1_in = clamp_to_width(N1, 16)
        N5_in = clamp_to_width(N5, 16)
        N10_in = clamp_to_width(N10, 16)
        N25_in = clamp_to_width(N25, 16)
        
        # Check expected result against the SCALED inputs (logic might differ if original overflowed)
        # For the purpose of the test, we assume the HDL implements the scaled logic.
        # If the original problem requires >65535, we accept the clipped behavior or mark as test constraint.
        
        # Apply inputs
        dut.P_in.value = P_in
        dut.N1_in.value = N1_in
        dut.N5_in.value = N5_in
        dut.N10_in.value = N10_in
        dut.N25_in.value = N25_in
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done or timeout
        done = False
        for _ in range(100000): # Large cycle count for DP operations
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done = True
                break
        
        if not done:
            dut._log.error(f"Timeout waiting for done in {desc}")
            failed += 1
            continue
            
        # Read result
        if not is_value_defined(dut.result.value):
            dut._log.error(f"Result undefined in {desc}")
            failed += 1
            continue
            
        res = int(dut.result.value)
        
        # Determine expected for scaled inputs
        # We can run a quick python check for the scaled values to ensure consistency
        # unless we know the test case is fixed.
        # Re-calculate expected for scaled inputs:
        def solve_py(p, n1, n5, n10, n25):
            # Simple DP for verification
            INF = 10**9
            dp = [-1] * (p + 1)
            dp[0] = 0
            coins = [(1, n1), (5, n5), (10, n10), (25, n25)]
            
            for val, count in coins:
                for amt in range(p, -1, -1):
                    if dp[amt] >= 0:
                        for k in range(1, count + 1):
                            next_amt = amt + k * val
                            if next_amt > p:
                                break
                            if dp[next_amt] < dp[amt] + k:
                                dp[next_amt] = dp[amt] + k
            return dp[p]

        calculated_exp = solve_py(P_in, N1_in, N5_in, N10_in, N25_in)
        
        # If the hardcoded expected matches the calculated expected, verify match.
        # If the test case is for large numbers (unclipped), the hardware result will match calculated_exp (clipped).
        # We prioritize the calculated expected value for the clipped inputs.
        
        if res != calculated_exp:
            dut._log.error(f"FAIL {desc}: Expected {calculated_exp}, got {res} (Scaled: P={P_in})")
            failed += 1
        else:
            passed += 1
            
    if failed > 0:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    else:
        dut._log.info(f"All {passed} tests passed")
