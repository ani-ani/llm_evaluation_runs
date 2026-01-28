import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
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

# Testbench constants
MOD = 1000000007
MAX_R = 32
MAX_W = 32
MAX_D = 32
CLK_NS = 10
MAX_CYCLES = 70000  # Slightly more than 65536 for safety

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Reference DP function for verification
def compute_expected(R, W, d, MOD):
    if R > MAX_R: R = MAX_R
    if W > MAX_W: W = MAX_W
    if d > MAX_D: d = MAX_D
    
    # DP[r][w][last] where last: 0=white, 1=red
    dp = [[[0, 0] for _ in range(W + 1)] for _ in range(R + 1)]
    dp[0][0][0] = 1
    dp[0][0][1] = 1
    
    for r in range(R + 1):
        for w in range(W + 1):
            # If last was white (0), we can add a red pile
            if dp[r][w][0] > 0:
                for k in range(1, min(d, R - r) + 1):
                    dp[r + k][w][1] = (dp[r + k][w][1] + dp[r][w][0]) % MOD
            
            # If last was red (1), we can add a white pile
            if dp[r][w][1] > 0:
                for k in range(1, (W - w) + 1):
                    dp[r][w + k][0] = (dp[r][w + k][0] + dp[r][w][1]) % MOD
    
    return (dp[R][W][0] + dp[R][W][1]) % MOD

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_wine_arrangements(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
        
        # Check ready signal
        if has_signal(dut, 'ready'):
            await RisingEdge(dut.clk)
            if int(dut.ready.value) != 1:
                raise TestFailure("Module not ready after reset")
    
    # Test cases: (R, W, d, expected_result)
    test_cases = [
        (2, 2, 1, 3),
        (2, 2, 2, 6),
        (1, 1, 1, 2),   # R1,W1 or W1,R1
        (1, 1, 2, 2),   # Same as above since d≥1
        (3, 1, 1, 1),   # Only R1,W1,R1 (3 red, 1 white)
        (0, 0, 5, 0),   # Edge: empty - but constraints say ≥1
        (1, 0, 1, 1),   # Only red pile
        (0, 1, 5, 1),   # Only white pile
        (2, 1, 1, 2),   # R1,W1,R1 (2 red, 1 white) or R1,W1 (2 red, 1 white) wait, let me recalc
        # For R=2,W=1,d=1: Only R1,W1,R1 possible? No, W=1 so can't have R1,W1,R1
        # R1,W1 uses 1R,1W but R=2,W=1. W=1 so W1 is full.
        # Can't do R1,W1,R1 because W1 uses only 1 white, leaving 0 for later
        # Actually: R1,W1,R1 means 2 red, 1 white. Valid!
        # But wait: R1,W1 uses 1R,1W. Then R1 uses another red. Total 2R,1W. Valid.
        # So (2,1,1) -> 1 way? No, (R1,W1,R1) is one sequence.
        # Also (W1,R1,R1)? No, piles alternate.
        # (R1,W1) - uses 1R,1W, leaves 1R unused
        # (W1,R1) - uses 1W,1R, leaves 1R unused
        # (R1,W1,R1) - uses 2R,1W - Valid!
        # So only 1 way? Wait, my DP says:
        # DP[0][0][0]=1, DP[0][0][1]=1
        # Add R1: DP[1][0][1] += 1
        # Add W1: DP[0][1][0] += 1
        # From DP[1][0][1]: Add W1 -> DP[1][1][0] += 1
        # From DP[0][1][0]: Add R1 -> DP[1][1][1] += 1
        # From DP[1][1][0]: Add R1 -> DP[2][1][1] += 1
        # From DP[1][1][1]: Add W1 -> No W left
        # Result DP[2][1][0] + DP[2][1][1] = 0 + 1 = 1
        # Okay, 1 way. Let me fix test case.
        (2, 1, 1, 1),
    ]
    
    passed = 0
    failed = 0
    
    for R, W, d, expected in test_cases:
        cocotb.log.info(f"Testing R={R}, W={W}, d={d}, expected={expected}")
        
        # Scale inputs to 16/8 bits for HDL
        R_scaled = clamp_to_width(R, 16)
        W_scaled = clamp_to_width(W, 16)
        d_scaled = clamp_to_width(d, 8)
        
        if is_seq:
            # Wait for ready
            max_wait = 1000
            for _ in range(max_wait):
                if is_value_defined(dut.ready.value) and int(dut.ready.value) == 1:
                    break
                await RisingEdge(dut.clk)
            else:
                raise TestFailure("Module not becoming ready")
            
            # Apply inputs
            dut.R_in.value = R_scaled
            dut.W_in.value = W_scaled
            dut.d_in.value = d_scaled
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            
            # Compute expected (Python reference)
            expected_computed = compute_expected(R, W, d, MOD)
            
            if result != expected_computed:
                raise TestFailure(f"Expected {expected_computed}, got {result} for R={R}, W={W}, d={d}")
            
            if result != expected:
                cocotb.log.warning(f"Result matches DP but differs from hardcoded: got {result}, hardcoded {expected}")
            
            passed += 1
        else:
            # Combinational: just apply and wait
            dut.R_in.value = R_scaled
            dut.W_in.value = W_scaled
            dut.d_in.value = d_scaled
            await Timer(100, units='ns')
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            expected_computed = compute_expected(R, W, d, MOD)
            
            if result != expected_computed:
                raise TestFailure(f"Expected {expected_computed}, got {result}")
            
            passed += 1
    
    cocotb.log.info(f"Tests passed: {passed}/{len(test_cases)}")
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")