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

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

# Test helper: parse input string to dut signals
async def set_input_ratios(dut, input_str):
    lines = input_str.strip().split('\n')
    for i in range(12):
        if i < len(lines):
            n, d = map(int, lines[i].split('/'))
            getattr(dut, f'ratio_n_{i}').value = clamp_to_width(n, 8)
            getattr(dut, f'ratio_d_{i}').value = clamp_to_width(d, 8)
        else:
            getattr(dut, f'ratio_n_{i}').value = 0
            getattr(dut, f'ratio_d_{i}').value = 0

async def wait_for_done(dut, max_cycles=3000):
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

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_gear_ratio(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    
    # Test Case 1: Provided example
    input1 = "19/13\n10/1\n19/14\n4/3\n20/7\n19/7\n20/13\n19/15\n10/7\n20/17\n19/2\n19/17\n"
    exp_front = [19, 20]
    exp_rear = [17, 15, 14, 13, 7, 2]
    
    # Test Case 2: Impossible case
    input2 = "1/1\n1/1\n1/1\n1/1\n1/1\n1/1\n1/1\n1/1\n1/1\n1/1\n1/1\n1/2\n"
    
    test_cases = [
        (input1, exp_front, exp_rear, "Example 1"),
        (input2, None, None, "Impossible case")
    ]
    
    passed = 0
    failed = 0
    
    for i, (inp, exp_f, exp_r, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Set inputs
            await set_input_ratios(dut, inp)
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(10000, units='ns')
            
            valid = int(dut.valid.value) if is_value_defined(dut.valid.value) else 0
            
            if exp_f is None:  # Expected impossible
                if valid == 1:
                    raise TestFailure(f"Expected impossible, but found solution")
                else:
                    cocotb.log.info("Correctly detected impossibility")
            else:  # Expected solution
                if valid != 1:
                    raise TestFailure(f"Expected valid=1, got {valid}")
                
                # Read front sprockets
                f0 = safe_int(dut.front0.value)
                f1 = safe_int(dut.front1.value)
                front_result = sorted([f0, f1])
                
                # Read rear sprockets
                rear_result = []
                for j in range(6):
                    rear_result.append(safe_int(getattr(dut, f'rear{j}').value))
                rear_result = sorted(rear_result)
                
                # Sort expected
                exp_f_sorted = sorted(exp_f)
                exp_r_sorted = sorted(exp_r)
                
                if front_result != exp_f_sorted or rear_result != exp_r_sorted:
                    raise TestFailure(f"Mismatch: Front got {front_result} exp {exp_f_sorted}, Rear got {rear_result} exp {exp_r_sorted}")
                
                cocotb.log.info(f"Success: Front {front_result}, Rear {rear_result}")
            
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")

# Additional test for scaling
@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_scaling(dut):
    """Verify outputs are within 1-10000 range"""
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    
    # Simple valid input
    input_str = "1/1\n1/2\n1/3\n1/4\n1/5\n1/6\n1/7\n1/8\n1/9\n1/10\n1/11\n1/12\n"
    
    await set_input_ratios(dut, input_str)
    
    if is_seq:
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await wait_for_done(dut)
    else:
        await Timer(10000, units='ns')
    
    valid = int(dut.valid.value) if is_value_defined(dut.valid.value) else 0
    
    if valid == 1:
        f0 = safe_int(dut.front0.value)
        f1 = safe_int(dut.front1.value)
        if f0 > 10000 or f1 > 10000:
            raise TestFailure(f"Front sprocket {max(f0,f1)} exceeds 10000")
        
        for j in range(6):
            r = safe_int(getattr(dut, f'rear{j}').value)
            if r > 10000:
                raise TestFailure(f"Rear sprocket {r} exceeds 10000")
        cocotb.log.info("All sprockets within 10000 limit")
    else:
        cocotb.log.info("No solution found (acceptable for this input)")
