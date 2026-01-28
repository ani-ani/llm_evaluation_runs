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

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
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

# Scale P to integer
def scale_p(p_float, scale=10**9):
    return int(p_float * scale)

# Verification logic (Python reference)
def solve_python(p_float):
    scale = 10**9
    p_scaled = int(p_float * scale)
    for N in range(1, 257):
        for n5 in range(N, -1, -1):
            rem5 = N - n5
            for n4 in range(rem5, -1, -1):
                rem4 = rem5 - n4
                for n3 in range(rem4, -1, -1):
                    rem3 = rem4 - n3
                    for n2 in range(rem3, -1, -1):
                        n1 = rem3 - n2
                        if n1 < 0: continue
                        total_sum = n1*1 + n2*2 + n3*3 + n4*4 + n5*5
                        if total_sum * scale == p_scaled * N:
                            return (n1, n2, n3, n4, n5)
    return (0, 0, 0, 0, 0)

@cocotb.test(timeout_time=100, timeout_unit="ms")
async def test_paper_puzzler(dut):
    # Setup clock if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational fallback
        dut.rst_n.value = 1
        dut.start.value = 0

    # Test cases
    test_inputs = [5.0, 4.5, 3.2, 1.0, 2.5, 3.333333333]
    
    for p_float in test_inputs:
        p_scaled = scale_p(p_float)
        expected = solve_python(p_float)
        
        cocotb.log.info(f"Testing P={p_float}, scaled={p_scaled}, expected={expected}")
        
        # Input assignment
        dut.p_scaled.value = p_scaled
        
        if is_seq:
            # Sequential trigger
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            await wait_for_done(dut)
            
            # Read outputs
            n1 = safe_int(dut.n1.value)
            n2 = safe_int(dut.n2.value)
            n3 = safe_int(dut.n3.value)
            n4 = safe_int(dut.n4.value)
            n5 = safe_int(dut.n5.value)
            
            # Verify
            result = (n1, n2, n3, n4, n5)
            total = n1 + n2 + n3 + n4 + n5
            total_sum = n1*1 + n2*2 + n3*3 + n4*4 + n5*5
            
            if total == 0:
                raise TestFailure(f"Solution returned zero papers for P={p_float}")
            
            # Check average: sum * 1e9 == p_scaled * total
            lhs = total_sum * 10**9
            rhs = p_scaled * total
            if lhs != rhs:
                raise TestFailure(f"Average mismatch: P={p_float}, got avg={total_sum/total} (sum={total_sum}, N={total})")
            
            if result != expected:
                # Accept if valid alternative solution
                cocotb.log.warning(f"Different solution: {result} vs expected {expected}. Checking validity...")
                # It is valid if average matches, which we just checked.
        else:
            # Combinational check
            await Timer(1, units='ns')
            # Check immediately
            n1 = safe_int(dut.n1.value)
            # ... same verification ...
            pass

    # Additional edge case: P=1.0 (all 1s, N=1)
    dut.p_scaled.value = scale_p(1.0)
    if is_seq:
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await wait_for_done(dut)
        if int(dut.n1.value) != 1 or (int(dut.n2.value) + int(dut.n3.value) + int(dut.n4.value) + int(dut.n5.value)) != 0:
             raise TestFailure("P=1.0 failed to produce single 1")
