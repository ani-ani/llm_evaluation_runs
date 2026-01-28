import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
from random import randint

MOD = 10**9 + 7

# Helper functions

def is_value_defined(v):
    try:
        int(v)
        return True
    except:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except:
        return default

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

# Python reference implementation
def solve_python(N, K, MOD):
    # Find divisors
    div = []
    i = 1
    while i * i <= N:
        if N % i == 0:
            div.append(i)
            if i * i != N:
                div.append(N // i)
        i += 1
    div.sort()
    
    # Compute f(d) = K^ceil(d/2)
    f = {}
    for d in div:
        exp = (d + 1) // 2
        f[d] = pow(K, exp, MOD)
    
    # Inclusion-exclusion to get f_clean
    f_clean = {}
    for d in div:
        val = f[d]
        for e in div:
            if e >= d:
                break
            if d % e == 0:
                val = (val - f_clean[e]) % MOD
        f_clean[d] = val
    
    # Sum contributions
    ans = 0
    for d in div:
        if d % 2 == 0:
            contrib = (d // 2) * f_clean[d]
        else:
            contrib = d * f_clean[d]
        ans = (ans + contrib) % MOD
    
    return ans

async def write_divisors(dut, divisors):
    """Write divisors to internal array"""
    for i, d in enumerate(divisors[:256]):
        if hasattr(dut, f'div_array_{i}'):
            getattr(dut, f'div_array_{i}').value = clamp_to_width(d, 16)
        elif hasattr(dut, 'div_array'):
            dut.div_array[i].value = clamp_to_width(d, 16)

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(3):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=70000):
    """Wait for done signal with timeout"""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_cyclic_palindrome(dut):
    """Test cyclic palindrome counter"""
    # Setup clock
    if has_signal(dut, 'clk'):
        clock = Clock(dut.clk, 10, units='ns')  # 100MHz
        cocotb.start_soon(clock.start())
    else:
        # Combinational module
        clock = None
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (N, K, expected_result)
    test_cases = [
        (4, 2, 6),
        (1, 10, 10),
        (6, 3, 75),
        (1, 1, 1),
        (2, 61108425, 61108425),
        (3, 563031691, 427796732),
    ]
    
    passed = 0
    failed = 0
    
    for i, (N_in, K_in, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: N={N_in}, K={K_in}")
        
        try:
            # Compute reference
            expected_ref = solve_python(N_in, K_in, MOD)
            if expected_ref != expected:
                cocotb.log.warning(f"Reference check: expected {expected}, got {expected_ref}")
            
            # Write inputs
            if has_signal(dut, 'N_in'):
                dut.N_in.value = clamp_to_width(N_in, 32)
            if has_signal(dut, 'K_in'):
                dut.K_in.value = clamp_to_width(K_in, 32)
            if has_signal(dut, 'MOD_in'):
                dut.MOD_in.value = clamp_to_width(MOD, 32)
            
            # Start computation
            if clock:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                # Combinational - just wait
                await Timer(1000, units='ns')
            
            # Read result
            if is_value_defined(dut.result.value):
                result = int(dut.result.value) % MOD
            else:
                raise TestFailure("Result signal undefined")
            
            # Check result
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"PASS: Result = {result}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL Test {i+1}: {e}")
            failed += 1
            
    if failed > 0:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    
    cocotb.log.info(f"All tests passed: {passed}/{len(test_cases)}")

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_large_values(dut):
    """Test with large N and K values"""
    if has_signal(dut, 'clk'):
        clock = Clock(dut.clk, 10, units='ns')
        cocotb.start_soon(clock.start())
        await reset_dut(dut)
    
    # Test: N=1000000000, K=1000000000
    N_in = 1000000000
    K_in = 1000000000
    expected = 875699961
    
    cocotb.log.info(f"Large test: N={N_in}, K={K_in}")
    
    if has_signal(dut, 'N_in'):
        dut.N_in.value = clamp_to_width(N_in, 32)
    if has_signal(dut, 'K_in'):
        dut.K_in.value = clamp_to_width(K_in, 32)
    if has_signal(dut, 'MOD_in'):
        dut.MOD_in.value = clamp_to_width(MOD, 32)
    
    if has_signal(dut, 'clk'):
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await wait_for_done(dut, max_cycles=70000)
    else:
        await Timer(10000, units='ns')
    
    if is_value_defined(dut.result.value):
        result = int(dut.result.value) % MOD
        if result != expected:
            raise TestFailure(f"Large value test: Expected {expected}, got {result}")
        cocotb.log.info(f"Large value test PASSED: {result}")
    else:
        raise TestFailure("Result undefined for large test")
