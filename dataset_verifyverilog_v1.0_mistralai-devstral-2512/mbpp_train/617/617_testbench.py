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
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_min_jumps(dut):
    # Setup
    CLK_NS = 10
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Python reference implementation
    def min_Jumps(steps, d):
        (a, b) = steps
        temp = a 
        a = min(a, b) 
        b = max(temp, b) 
        if (d >= b): 
            return (d + b - 1) / b 
        if (d == 0): 
            return 0
        if (d == a): 
            return 1
        else:
            return 2

    test_cases = [
        ((3, 4), 11, 3.5),
        ((3, 4), 0, 0),
        ((11, 14), 11, 1),
        ((1, 1), 5, 5),
        ((10, 10), 9, 2),
        ((2, 5), 2, 1),
        ((2, 5), 5, 1)
    ]

    passed = 0
    failed = 0

    for i, ((s_a, s_b), d_val, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: steps=({s_a}, {s_b}), d={d_val}")
        
        # Inputs
        dut.step_a.value = clamp_to_width(s_a, 16)
        dut.step_b.value = clamp_to_width(s_b, 16)
        dut.d.value = clamp_to_width(d_val, 16)
        
        # Trigger
        if has_signal(dut, 'start') and has_signal(dut, 'clk'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            await wait_for_done(dut)
        else:
            await Timer(100, units='ns')
        
        # Read Result
        if not is_value_defined(dut.result.value):
            cocotb.log.error(f"FAIL: Result undefined for case {i+1}")
            failed += 1
            continue
            
        hdl_result = int(dut.result.value)
        
        # Convert expected Python float to fixed-point Q16.16 integer
        # Q16.16: value * 2^16
        expected_fixed = int(expected * 65536 + 0.5) # Add 0.5 for rounding if needed, though prompt implies strict math
        
        # Allow small epsilon for float precision or just check integer part if fractional is tricky
        # The problem logic uses ceiling division for integer results (e.g. 11/4 = 3.5 in float, but logic says 3.5).
        # In hardware integer math, (11+4-1)/4 = 14/4 = 3. 
        # Wait, the prompt example expects 3.5 for 11/4. 
        # The logic `(d + b - 1) / b` is usually ceiling division for integers. 
        # If the example expects 3.5, it implies true division.
        # However, integer division in Verilog truncates. 
        # To get 3.5 (3.5 * 65536 = 229376), we need fractional bits.
        # Since inputs are integers, the result of division is either integer or X.5 (if b is 2,4... and d is odd).
        # Let's check if the test case expects 3.5 (11/4). 
        # (11+4-1) = 14. 14/4 = 3 remainder 2. 
        # In Q16.16: 14 << 16 / 4 = 229376. 
        # 3.5 * 65536 = 229376. Correct.
        
        # However, if the division is `d / b` (true division), the prompt logic `d + b - 1 / b` is confusing.
        # Usually that formula is for ceiling integer division.
        # If the requirement is 3.5, we must implement proper fixed-point division.
        
        # Checking result: 
        # If expected is 3.5 (229376) and HDL gives 3 (196608), it fails.
        # HDL logic should be: Result = ((d + b - 1) << 16) / b  (for Q16.16 output).
        
        # Let's verify the calculation logic in Python for Q16.16:
        if d_val >= max(s_a, s_b) and max(s_a, s_b) > 0:
            b = max(s_a, s_b)
            # The prompt says: return (d + b - 1) / b
            # For 11, 4: (11+4-1)/4 = 14/4 = 3.5
            # This implies floating point arithmetic or fixed point.
            # To simulate this in integer logic: ((d + b - 1) * 65536) / b
            python_fixed = int(((d_val + b - 1) * 65536) / b)
            # Note: integer division in Python truncates. 14/4 is 3. 
            # To get 3.5, the formula must be interpreted as floating point.
            # In HDL: (d_val + b - 1) << 16 / b.
        
        # Calculate expected integer representation for verification
        # If the problem implies floating point, we convert to fixed point.
        # 3.5 -> 229376
        # 0 -> 0
        # 1 -> 65536
        # 2 -> 131072
        
        # Let's recalculate expected based on prompt logic but output as fixed point Q16.16
        
        temp_a = s_a
        min_a = min(s_a, s_b)
        max_b = max(temp_a, s_b)
        
        calc_val = 0
        if d_val >= max_b and max_b > 0:
            # (d + b - 1) / b. 
            # To get .5 precision, we scale numerator.
            # 3.5 * 65536 = 229376
            # 14 / 4 = 3.5.  
            # Calculation: (14 * 65536) / 4 = 229376
            calc_val = int(((d_val + max_b - 1) << 16) / max_b)
        elif d_val == 0:
            calc_val = 0
        elif d_val == min_a:
            calc_val = 1 << 16
        else:
            calc_val = 2 << 16
            
        if hdl_result != calc_val:
            cocotb.log.error(f"FAIL: Case {i+1}. Expected {calc_val} (fixed), got {hdl_result}. Steps: ({s_a}, {s_b}), d: {d_val}")
            failed += 1
        else:
            passed += 1
            
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")