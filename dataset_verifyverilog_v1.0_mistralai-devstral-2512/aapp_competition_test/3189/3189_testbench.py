import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 16
MAX_N = 16
MAX_M = 8
CLK_NS = 10
MAX_CYCLES = 2000
MODULUS = 1000003

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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

def count_permutations_python(n, m, observations):
    """Reference implementation for validation"""
    if n == 0:
        return 1
    
    # Check consistency of observations
    for obs in observations:
        sw = obs[0]
        lw = obs[1]
        for i in range(n):
            if (sw >> i) & 1 != (lw >> i) & 1:
                # This observation requires specific constraints
                pass
    
    # DP: dp[mask] = number of ways to assign first popcount(mask) switches
    # to lights indicated by bits in mask
    dp = [0] * (1 << n)
    dp[0] = 1
    
    for mask in range(1 << n):
        if dp[mask] == 0:
            continue
        
        switch_idx = bin(mask).count('1')  # Next switch to assign
        if switch_idx >= n:
            continue
            
        # Try assigning switch_idx to each unused light
        for light_idx in range(n):
            if (mask >> light_idx) & 1:
                continue  # Light already used
            
            # Check if this assignment is consistent with all observations
            valid = True
            for obs in observations:
                sw_bit = (obs[0] >> switch_idx) & 1
                lw_bit = (obs[1] >> light_idx) & 1
                if sw_bit != lw_bit:
                    valid = False
                    break
            
            if valid:
                new_mask = mask | (1 << light_idx)
                dp[new_mask] = (dp[new_mask] + dp[mask]) % MODULUS
    
    return dp[(1 << n) - 1]

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_wiring_count(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases
    test_cases = [
        # (n, m, observations, expected_result, description)
        (3, 1, [(0b110, 0b011)], 2, "Example 1: 3 switches, 1 observation"),
        (4, 2, [(0b1000, 0b1000), (0b0000, 0b0010)], 0, "Example 2: inconsistent observations"),
        (0, 0, [], 1, "Edge case: 0 switches"),
        (1, 0, [], 1, "Single switch, no observations"),
        (2, 0, [], 2, "Two switches, no observations (2! = 2)"),
        (1, 1, [(0b1, 0b1)], 1, "Single switch, matching observation"),
        (2, 1, [(0b11, 0b11)], 2, "Two switches, both 1 in observation (must map 1->1, 2->1) - actually 2 ways"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, m, observations, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        
        try:
            # Set inputs
            dut.n.value = n
            dut.m.value = m
            
            # Clear observation matrices
            for obs_idx in range(MAX_M):
                for switch_idx in range(MAX_N):
                    sig_name = f'obs_switch_{obs_idx}_{switch_idx}'
                    if has_signal(dut, sig_name):
                        getattr(dut, sig_name).value = 0
                    
                    sig_name = f'obs_light_{obs_idx}_{switch_idx}'
                    if has_signal(dut, sig_name):
                        getattr(dut, sig_name).value = 0
            
            # Set observation matrices
            for obs_idx, (sw_mask, lw_mask) in enumerate(observations):
                for bit_idx in range(n):
                    sw_bit = (sw_mask >> bit_idx) & 1
                    lw_bit = (lw_mask >> bit_idx) & 1
                    
                    sw_sig_name = f'obs_switch_{obs_idx}_{bit_idx}'
                    if has_signal(dut, sw_sig_name):
                        getattr(dut, sw_sig_name).value = sw_bit
                    
                    lw_sig_name = f'obs_light_{obs_idx}_{bit_idx}'
                    if has_signal(dut, lw_sig_name):
                        getattr(dut, lw_sig_name).value = lw_bit
            
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
            
            # Verify
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {desc} - {e}")
            failed += 1
        
        # Reset between tests
        await reset_dut(dut)
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {len(test_cases)}")
    
    cocotb.log.info(f"All {passed} tests passed!")

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_large_n(dut):
    """Test with n=10, no observations (should be 10! mod 1000003)"""
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    n = 10
    m = 0
    expected = 3628800 % 1000003  # 10!
    
    dut.n.value = n
    dut.m.value = m
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    await wait_for_done(dut)
    
    result = int(dut.result.value)
    
    if result != expected:
        raise TestFailure(f"Expected {expected}, got {result}")
    
    cocotb.log.info(f"n=10, m=0: Result {result} matches expected {expected}")