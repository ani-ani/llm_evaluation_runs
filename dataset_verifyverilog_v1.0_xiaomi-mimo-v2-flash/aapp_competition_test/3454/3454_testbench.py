import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Modulo constant
MOD = 100003

# Helper functions
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

async def wait_for_done(dut, max_cycles=2000000): # Large timeout for 1M cycles
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

def solve_python(N, M, c):
    # Python reference for the DP problem
    # H_limit is M - c[N-1] (since c is 0-indexed)
    if not c: return 0, 0
    H_limit = M - c[-1]
    
    # dp[h] stores count for current column
    # Initialize for column 0
    dp = [0] * (H_limit + 1)
    dp[0] = 1
    
    total_zeros = 0
    
    for i in range(N):
        # H_max for column i (1-indexed in problem, so i+1)
        H_max = M - c[i]
        if H_max > H_limit: H_max = H_limit
        
        new_dp = [0] * (H_limit + 1)
        
        # Calculate new values
        # dp[i][h] = dp[i-1][h] + dp[i][h-1]
        # Since we iterate h increasing, dp[h] on RHS represents dp[i][h-1] (updated) and dp[i-1][h] (old)
        
        # We need to be careful with indices.
        # Let's do a clean calculation for each h
        
        running_sum = 0
        for h in range(H_max + 1):
            # dp[i][h] += dp[i-1][h]
            val = dp[h]
            # dp[i][h] += dp[i][h-1] -> this is the new_dp[h-1] (left-to-right accumulation)
            if h > 0:
                val = (val + new_dp[h-1]) % MOD
            
            new_dp[h] = val
            if val == 0:
                total_zeros += 1
        
        dp = new_dp
        
    return total_zeros, dp[H_limit]

@cocotb.test(timeout_time=30000, timeout_unit="ms")
async def test_pokenom(dut):
    # Setup signals
    DATA_WIDTH_N = 10
    DATA_WIDTH_M = 10
    DATA_WIDTH_C = 10
    DATA_WIDTH_RES = 17
    
    # Check mandatory signals
    assert has_signal(dut, 'clk'), "Missing clk signal"
    assert has_signal(dut, 'rst_n'), "Missing rst_n signal"
    assert has_signal(dut, 'start'), "Missing start signal"
    assert has_signal(dut, 'done'), "Missing done signal"
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    # Test Cases
    test_cases = [
        (3, 3, [3, 2, 1]),
        (4, 4, [4, 3, 1, 0]),
    ]
    
    for idx, (N, M, c_list) in enumerate(test_cases):
        cocotb.log.info(f"Running test case {idx+1}: N={N}, M={M}, c={c_list}")
        
        # Calculate expected values
        exp_X, exp_Y = solve_python(N, M, c_list)
        cocotb.log.info(f"Expected: X={exp_X}, Y={exp_Y}")
        
        # 1. Provide N and M
        # Assuming inputs are latched on start or available continuously
        # We will drive N, M, and c serially if required by spec, or parallel.
        # The prompt suggests `c_in` is likely a serial stream or indexed.
        # Given the complexity, let's assume we drive them serially on `c_in` with `start`.
        # Wait, usually N and M are separate. 
        # Let's assume standard interface: N, M are inputs, c_in is serial stream.
        
        dut.N.value = clamp_to_width(N, DATA_WIDTH_N)
        dut.M.value = clamp_to_width(M, DATA_WIDTH_M)
        dut.c_in.value = 0
        
        # Drive sequence c
        # Since the module needs to receive c, we might need to wait for a 'load' signal or do it before start.
        # Let's assume we can drive c inputs in the first N cycles while start is high or just before.
        # To be safe, we will just drive `c_in` and assume the module samples it on rising edge when ready.
        # The prompt says `c_in` is an input. We'll drive it.
        
        # Let's assume the design has a state machine that reads N, M and then reads c.
        # We will drive c_in values on the clock edges.
        
        # For the test, we assume the DUT has a way to ingest c. 
        # If c_in is a single port, we might need to assert a 'load' signal or just drive it before start.
        # Let's assume we drive it in the first N cycles after start.
        
        # Actually, the prompt says: "c_in: 10-bit integer (input stream of sequence c, valid when index < N)"
        # This implies we need to feed c values one by one.
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Feed c sequence
        # We need to know when the DUT is ready to accept c.
        # If the DUT starts processing immediately, we might need to feed c on the fly.
        # Or if it buffers.
        # Let's assume the DUT accepts c_in values on the first N cycles of operation.
        
        for i, c_val in enumerate(c_list):
            dut.c_in.value = clamp_to_width(c_val, DATA_WIDTH_C)
            await RisingEdge(dut.clk)
            
        # After feeding c, we wait for done
        # Note: If the DUT processes in pipelined fashion, we might need to keep feeding or stop.
        # Given the "iterative with bounded loops" simplification, likely a state machine.
        # We'll wait for done.
        
        await wait_for_done(dut)
        
        # Check results
        if not is_value_defined(dut.result.value) or not is_value_defined(dut.X.value):
            raise TestFailure("Result or X is undefined")
            
        result = int(dut.result.value)
        X = int(dut.X.value)
        
        # Check against expected
        if X != exp_X:
             raise TestFailure(f"Test {idx+1} Failed: X mismatch. Expected {exp_X}, got {X}")
        
        # The problem asks for Y mod 100003
        if result != exp_Y:
            raise TestFailure(f"Test {idx+1} Failed: Y mismatch. Expected {exp_Y}, got {result}")
            
        cocotb.log.info(f"Test {idx+1} Passed: X={X}, Y={result}")
        
        # Reset for next test
        await reset_dut(dut)