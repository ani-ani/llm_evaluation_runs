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
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=10000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Logic for finding optimal subsequence in Python to verify HDL
def solve_python(s, k):
    n = len(s)
    best_f = 1
    best_l = k
    best_val_num = 0
    best_val_den = 1
    
    # Check every possible start and length >= k
    for start in range(n):
        ones = 0
        for length in range(1, n - start + 1):
            if s[start + length - 1] == '1':
                ones += 1
            if length >= k:
                # Compare ones/length > best_val_num/best_val_den
                # Cross multiply: ones * best_val_den > best_val_num * length
                if ones * best_val_den > best_val_num * length:
                    best_val_num = ones
                    best_val_den = length
                    best_f = start + 1
                    best_l = length
    return best_f, best_l

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_max_density_subarray(dut):
    # Setup
    if not has_signal(dut, 'clk'):
        await Timer(100, units='ns')
        return
        
    CLK_NS = 10
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Constants based on spec
    MAX_LEN = 256
    
    # Test cases
    test_cases = [
        ("01", 1),
        ("0110011", 4),
        ("111000", 3),
        ("01010101", 2)
    ]
    
    for s_str, k_val in test_cases:
        cocotb.log.info(f"Testing s='{s_str}', k={k_val}")
        
        # Expected result
        exp_f, exp_l = solve_python(s_str, k_val)
        
        # Prepare inputs
        n = len(s_str)
        
        # Write string to dut array (s_0, s_1... or s[0])
        # Try to handle different array styles
        for i in range(n):
            val = 1 if s_str[i] == '1' else 0
            # Check if array is indexed (dut.s[i]) or flat (dut.s_i)
            if has_signal(dut, f's_{i}'):
                getattr(dut, f's_{i}').value = val
            elif hasattr(dut.s, '__getitem__'):
                dut.s[i].value = val
            else:
                raise TestFailure("Cannot access input array s")
                
        # Set k
        dut.k.value = k_val
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read result
        if not (has_signal(dut, 'start_idx') and has_signal(dut, 'length')):
             raise TestFailure("Output signals missing")
             
        res_f = int(dut.start_idx.value)
        res_l = int(dut.length.value)
        
        if res_f != exp_f or res_l != exp_l:
            raise TestFailure(f"Mismatch: Expected ({exp_f}, {exp_l}), Got ({res_f}, {res_l})")
            
        # Reset for next test
        await reset_dut(dut)
