import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants
MOD = 1000000007
CLK_NS = 10
MAX_CYCLES = 10000
DATA_WIDTH_N = 4  # N up to 10
DATA_WIDTH_C = 8  # C up to 256 scaled
RESULT_WIDTH = 32

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    v_int = int(v)
    if v_int < 0: v_int = 0
    return min(max_val, v_int)

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    if has_signal(dut, 'busy'):
        await Timer(1, units='ns')
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=10000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

def dp_reference(N, C):
    """Reference DP computation."""
    # Scale C for DP if needed (but reference uses actual C)
    C_actual = C
    if N > 10 or C_actual > 10000:
        # Scale down for testbench reference
        N = min(N, 10)
        C_actual = min(C, 256)
    dp = [ [0] * (C_actual + 1) for _ in range(N + 1) ]
    dp[0][0] = 1
    for n in range(1, N + 1):
        for c in range(C_actual + 1):
            total = 0
            max_k = min(c, n - 1)
            for k in range(max_k + 1):
                total = (total + dp[n-1][c-k]) % MOD
            dp[n][c] = total
    return dp[N][C_actual]

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_inversion_count(dut):
    # Clock setup
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational
        await Timer(100, units='ns')
    
    # Test cases: N, C, Expected (scaled if needed)
    # Note: For hardware, C is scaled to 8-bit (0-256)
    test_cases = [
        (10, 1, 9),     # Scaled C=1
        (4, 3, 6),      # Scaled C=3
        (9, 13, 17957), # Scaled C=13
        (2, 0, 1),      # Edge case
        (2, 1, 1),      # Edge case
        (3, 2, 2),      # Edge case
        (1, 0, 1),      # Edge case
        (1, 5, 0),      # Invalid C > max
    ]
    
    passed = 0
    failed = 0
    
    for i, (N, C, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: N={N}, C={C}")
        try:
            # Scale C for input (max 256)
            C_scaled = min(C, 256)
            
            # Set inputs
            if has_signal(dut, 'N'):
                dut.N.value = clamp_to_width(N, DATA_WIDTH_N)
            if has_signal(dut, 'C'):
                dut.C.value = clamp_to_width(C_scaled, DATA_WIDTH_C)
            
            if has_signal(dut, 'clk'):
                # Sequential test
                if has_signal(dut, 'start'):
                    dut.start.value = 1
                    await RisingEdge(dut.clk)
                    dut.start.value = 0
                    await wait_for_done(dut)
                else:
                    await Timer(1000, units='ns') # Wait for pipeline
            else:
                # Combinational
                await Timer(100, units='ns')
            
            # Read result
            if not has_signal(dut, 'result'):
                raise TestFailure("Result signal missing")
            
            result_raw = int(dut.result.value)
            result = result_raw & ((1 << RESULT_WIDTH) - 1) # Ensure unsigned
            
            # Calculate expected (scaled)
            expected_scaled = dp_reference(N, C_scaled)
            
            # For C > 256, expected is 0 (clamped)
            if C > 256:
                expected_scaled = 0
            
            if result != expected_scaled:
                raise TestFailure(f"Expected {expected_scaled}, got {result} (scaled N={N}, C={C_scaled})")
            
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL Test {i+1}: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed+failed}")