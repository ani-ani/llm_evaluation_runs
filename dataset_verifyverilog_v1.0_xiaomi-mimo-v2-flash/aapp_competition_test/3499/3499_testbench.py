import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants
MOD = 1000000007
CLK_NS = 10
MAX_CYCLES = 500

# Helpers
def is_value_defined(v):
    try:
        int(v)
        return True
    except (ValueError, TypeError):
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except (ValueError, TypeError):
        return default

def clamp_to_width(v, bits):
    mask = (1 << bits) - 1
    return v & mask

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut, cycles=2):
    """Reset the DUT"""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    """Wait for done signal"""
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Reference implementation for testing
def reference_solution(N, S):
    """Reference Python implementation"""
    MOD = 1000000007
    if N == 0:
        # Empty S, need palindromes of length 0 -> 1 way (empty string)
        return 1
    
    # Convert S to list of indices
    s_indices = [ord(c) - ord('A') for c in S]
    
    # Precompute powers of 26
    pow26 = [1]
    for i in range(1, N + 1):
        pow26.append((pow26[-1] * 26) % MOD)
    
    # dp[pos][match] = count
    dp = [[0] * (N + 1) for _ in range(N + 1)]
    dp[0][0] = 1
    
    # Build first half
    for pos in range(N):
        for match in range(N + 1):
            if dp[pos][match] == 0:
                continue
            for letter in range(26):
                new_match = match
                if match < N and letter == s_indices[match]:
                    new_match = match + 1
                dp[pos + 1][new_match] = (dp[pos + 1][new_match] + dp[pos][match]) % MOD
    
    # Count valid strings
    result = 0
    for match in range(N + 1):
        ways = dp[N][match]
        if ways == 0:
            continue
        # Remaining positions can be any letter
        remaining = N - match
        if remaining >= 0:
            result = (result + ways * pow26[remaining]) % MOD
    
    # Multiply by 26^N for second half
    result = (result * pow26[N]) % MOD
    
    return result

def str_to_bits(s):
    """Convert string to 26-bit vector"""
    bits = 0
    for c in s:
        idx = ord(c) - ord('A')
        bits |= (1 << idx)
    return bits

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_palin_seq(dut):
    """Test palindrome subsequence counter"""
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    test_cases = [
        (0, "", 1),  # Edge case: empty string
        (2, "AA", 51),  # Example from problem
        (2, "AB", 2),   # Example from problem
        (1, "A", 26),   # Simple case: single A
    ]
    
    passed = 0
    failed = 0
    
    for i, (N, S, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: N={N}, S='{S}'")
        try:
            # Calculate reference
            ref_result = reference_solution(N, S)
            cocotb.log.info(f"  Reference: {ref_result}")
            
            # Setup inputs
            s_bits = str_to_bits(S)
            s_len = len(S)
            
            # Apply to DUT
            dut.s_chars.value = clamp_to_width(s_bits, 26)
            dut.s_len.value = clamp_to_width(s_len, 3)
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut, MAX_CYCLES)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            dut_result = int(dut.result.value)
            cocotb.log.info(f"  DUT result: {dut_result}")
            
            if dut_result != expected:
                raise TestFailure(f"Expected {expected}, got {dut_result}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
            
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed, {passed} passed")
    
    cocotb.log.info(f"All {passed} tests passed!")