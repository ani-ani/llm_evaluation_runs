import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'mult_valid'): dut.mult_valid.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=10000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Python Solution Reference (for verification)
def python_solution(a, b, h, w, n, multipliers):
    if (h >= a and w >= b) or (h >= b and w >= a):
        return 0
    
    # Sort multipliers descending, keep at most 32 (or n if smaller)
    multipliers.sort(reverse=True)
    n = min(n, 32)
    multipliers = multipliers[:n]
    
    # BFS: State is (h, w)
    # We track visited states to avoid cycles
    visited = set()
    visited.add((h, w))
    
    current_states = [(h, w)]
    
    for i in range(n):
        next_states = []
        mult = multipliers[i]
        
        for (curr_h, curr_w) in current_states:
            # Option 1: Multiply h
            new_h = curr_h * mult
            new_w = curr_w
            if new_h > 200000: new_h = 200000 # Clamp
            if (new_h >= a and new_w >= b) or (new_h >= b and new_w >= a):
                return i + 1
            if (new_h, new_w) not in visited:
                visited.add((new_h, new_w))
                next_states.append((new_h, new_w))
            
            # Option 2: Multiply w
            new_h = curr_h
            new_w = curr_w * mult
            if new_w > 200000: new_w = 200000 # Clamp
            if (new_h >= a and new_w >= b) or (new_h >= b and new_w >= a):
                return i + 1
            if (new_h, new_w) not in visited:
                visited.add((new_h, new_w))
                next_states.append((new_h, new_w))
        
        if not next_states:
            break
        current_states = next_states
        
    return -1

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_field_extension(dut):
    # Setup Clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    # Test Cases (scaled to 16-bit)
    test_cases = [
        (3, 3, 2, 4, 4, [2, 5, 4, 10], 1),
        (3, 3, 3, 3, 5, [2, 3, 5, 4, 2], 0),
        (5, 5, 1, 2, 3, [2, 2, 3], -1),
        (3, 4, 1, 1, 3, [2, 3, 2], 3),
        (100, 100, 1, 1, 2, [100000, 100000], 2) # Overflow handling check
    ]
    
    for i, (a, b, h, w, n, mults, expected) in enumerate(test_cases):
        cocotb.log.info(f"Running Test Case {i+1}: a={a}, b={b}, h={h}, w={w}, n={n}")
        
        # 1. Load Inputs
        dut.a_i.value = a
        dut.b_i.value = b
        dut.h_i.value = h
        dut.w_i.value = w
        dut.n_i.value = n
        
        # 2. Feed Multipliers sequentially
        if n > 0:
            dut.mult_valid.value = 1
            for idx, m in enumerate(mults):
                dut.mult_i.value = m
                await RisingEdge(dut.clk)
            dut.mult_valid.value = 0
        
        # 3. Start Computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # 4. Wait for done
        await wait_for_done(dut)
        
        # 5. Verify Result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {i+1}: Result undefined")
            
        result = int(dut.result.value)
        
        # Handle -1 mapping (using 255 or 0xFF)
        exp_val = expected if expected != -1 else 255
        
        if result != exp_val:
            # Double check with python solution to ensure test case correctness
            py_res = python_solution(a, b, h, w, n, mults[:n])
            if py_res != expected:
                 cocotb.log.warning(f"Test case {i+1} expected {expected} but Python solver says {py_res}. Check input constraints.")
            raise TestFailure(f"Test {i+1}: Expected {exp_val} ({expected}), got {result}")
        else:
            cocotb.log.info(f"Test {i+1} Passed: Result {result}")
