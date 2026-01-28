import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants
CLK_NS = 10
MAX_CYCLES = 2000

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    if bits >= 32: # Python int handles it
        return v
    max_val = (1 << bits) - 1
    return min(max_val, max(0, v))

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    if val < 0: return val + (1 << bits)
    return val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def float_to_fixed(f, frac=16):
    return int(f * (1 << frac))

def fixed_to_float(v, frac=16):
    return v / (1 << frac)

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_employee_team(dut):
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases from prompt
    # Case 1: k=1, n=2
    # emp1: s=1000, p=1, r=0
    # emp2: s=1, p=1000, r=1 (must pick emp1 to pick emp2)
    # Opt: Pick emp1 -> 1/1000 = 0.001
    # Opt: Pick emp2 (impossible without emp1, but k=1 so only emp1 or emp2 alone)
    # Wait, constraint: recommender must be in team OR CEO (0).
    # If we pick emp2, we need emp1. That's 2 people, but k=1. So emp2 is invalid.
    # If we pick emp1, recommender is CEO (0), valid. Result = 1/1000 = 0.001.
    
    # Case 2: k=2, n=3
    # 1: 1, 100, 0
    # 2: 1, 200, 0
    # 3: 1, 300, 0
    # All connected to CEO. Pick best 2: 200 + 300 / 1 + 1 = 500/2 = 250.

    # Inputs: k, n, s[16], p[16], r[16]
    
    test_cases = [
        {
            "k": 1, "n": 2,
            "s": [0, 1000, 1],
            "p": [0, 1, 1000],
            "r": [0, 0, 1],
            "expected": 0.001
        },
        {
            "k": 2, "n": 3,
            "s": [0, 1, 1, 1],
            "p": [0, 100, 200, 300],
            "r": [0, 0, 0, 0],
            "expected": 250.0
        }
    ]

    for i, tc in enumerate(test_cases):
        cocotb.log.info(f"Running Test Case {i+1}: k={tc['k']}, n={tc['n']}")
        
        # Set inputs
        dut.k.value = tc['k']
        dut.n.value = tc['n']
        
        # Set arrays (emp 0 is dummy/CEO, emp 1..n are inputs)
        # In Verilog, expect arrays indexed 0..15
        for j in range(tc['n'] + 1): # Include index 0
            if has_signal(dut, f'employee_salary_{j}'):
                getattr(dut, f'employee_salary_{j}').value = clamp_to_width(tc['s'][j], 16)
                getattr(dut, f'employee_productivity_{j}').value = clamp_to_width(tc['p'][j], 16)
                getattr(dut, f'employee_recommender_{j}').value = clamp_to_width(tc['r'][j], 4)
            # If it's an array bus, we might need different access, but spec says arrays. 
            # Since Verilog arrays are tricky in cocotb, we assume 'indexed' ports or the prompt handles it.
            # For this testbench, we assume the DUT has ports like arr[i] or arr_i.
            # If dut.employee_salary is an array:
            if has_signal(dut, 'employee_salary'):
                try:
                    dut.employee_salary[j].value = clamp_to_width(tc['s'][j], 16)
                    dut.employee_productivity[j].value = clamp_to_width(tc['p'][j], 16)
                    dut.employee_recommender[j].value = clamp_to_width(tc['r'][j], 4)
                except IndexError:
                    pass # Handle if size differs

        # Trigger
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut, 2000)
        
        # Check result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {i+1}: Result is undefined")
            
        result_int = int(dut.result.value)
        result_float = fixed_to_float(result_int, 16)
        
        cocotb.log.info(f"Result fixed: {result_int}, float: {result_float}")
        
        # Allow small error for floating point/imprecision
        expected = tc['expected']
        error = abs(result_float - expected)
        
        if error > 0.01: # Strict check for integer-heavy examples
             raise TestFailure(f"Test {i+1}: Expected {expected}, got {result_float}")
