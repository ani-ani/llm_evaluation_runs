import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH, MAX_N, CLK_NS, MAX_CYCLES = 4, 16, 10, 10000

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

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def write_a_array(dut, a_values, n):
    for i in range(MAX_N):
        val = a_values[i] if i < len(a_values) else 0
        dut.a[i].value = clamp_to_width(val, DATA_WIDTH)

def check_permutation(arr, n):
    """Check if arr is a valid permutation of 1..n"""
    if len(arr) != n: return False
    seen = set()
    for v in arr:
        if v < 1 or v > n or v in seen:
            return False
        seen.add(v)
    return True

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_solver(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    test_cases = [
        (5, [3,2,3,1,1], True),   # Should find solution
        (4, [3,1,1,4], False),    # Should be impossible
        (2, [1,2], True),         # n=2 edge case
        (1, [1], True),           # n=1 edge case
        (3, [1,1,1], True),       # n=3 with possible sums
    ]
    
    passed = failed = 0
    
    for tc_idx, (n, a_vals, should_find) in enumerate(test_cases):
        desc = f"n={n}, a={a_vals}, expected={'solution' if should_find else 'impossible'}"
        cocotb.log.info(f"Test {tc_idx+1}: {desc}")
        
        try:
            # Reset
            if is_seq:
                await reset_dut(dut, cycles=2)
            
            # Write inputs
            dut.n.value = n
            await write_a_array(dut, a_vals, n)
            
            if is_seq:
                # Start computation
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            # Read results
            if not is_value_defined(dut.valid.value):
                raise TestFailure("Valid signal undefined")
            
            valid = int(dut.valid.value)
            
            if should_find:
                if valid != 1:
                    raise TestFailure(f"Expected solution but got valid={valid}")
                
                # Read permutations
                pi_vals = []
                sigma_vals = []
                for i in range(n):
                    pi_vals.append(int(dut.pi[i].value))
                    sigma_vals.append(int(dut.sigma[i].value))
                
                # Validate permutations
                if not check_permutation(pi_vals, n):
                    raise TestFailure(f"pi is not a valid permutation: {pi_vals}")
                if not check_permutation(sigma_vals, n):
                    raise TestFailure(f"sigma is not a valid permutation: {sigma_vals}")
                
                # Validate sum constraint
                for i in range(n):
                    sum_val = pi_vals[i] + sigma_vals[i]
                    mod_val = sum_val % n
                    # Adjust: input values are 1..n, so modulo should map to 1..n
                    # Actually, (1+2) mod 2 = 1, but input expects values in 1..n
                    # Need to check: (π[i] + σ[i]) mod n should equal a[i]
                    # But a[i] is in 1..n, and mod n gives 0..n-1
                    # So we need to interpret a[i] as mod n, where a[i]=n means 0 mod n
                    expected = a_vals[i] % n
                    if expected == 0: expected = n
                    if mod_val == 0: mod_val = n
                    if mod_val != expected:
                        raise TestFailure(f"Sum constraint violated at i={i}: pi={pi_vals[i]}, sigma={sigma_vals[i]}, sum={sum_val}, mod={mod_val}, expected a[i]={a_vals[i]}")
                
                cocotb.log.info(f"Solution found: pi={pi_vals}, sigma={sigma_vals}")
            else:
                if valid != 0:
                    pi_vals = []
                    for i in range(n):
                        pi_vals.append(int(dut.pi[i].value))
                    raise TestFailure(f"Expected impossible but got valid=1 with pi={pi_vals}")
                cocotb.log.info("Correctly returned impossible")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL (Test {tc_idx+1}): {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} out of {passed+failed} tests failed")
    
    cocotb.log.info(f"All {passed} tests passed")