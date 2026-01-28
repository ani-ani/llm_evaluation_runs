import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
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
    max_val = (1 << bits) - 1
    v = int(v)
    return min(max_val, max(0, v))

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

# Algorithm implementation in Python for verification
def calculate_score(arr, n):
    if n == 0: return 0
    stack = [arr[0]]
    score = 0
    for i in range(1, n):
        while len(stack) > 1 and stack[-1] <= min(arr[i], stack[-2]):
            score += min(arr[i], stack[-2])
            stack.pop()
        stack.append(arr[i])
    
    # Process remaining stack
    for i in range(1, len(stack) - 1):
        score += min(stack[i-1], stack[i+1])
    
    return score

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=300):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_stack_removal(dut):
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Test cases: (arr, n, expected_score)
    # We scale n to max 16
    test_cases = [
        ([3, 1, 5, 2, 6], 5, 11),
        ([1, 2, 3, 4, 5], 5, 6),
        ([1, 100, 101, 100, 1], 5, 102),
        ([96, 66, 8, 18, 30, 48, 34, 11, 37, 42], 10, 299),
        ([87], 1, 0),
        ([93, 51], 2, 0),
        ([31, 19, 5], 3, 5),
        ([86, 21, 58, 60], 4, 118),
        ([21, 6, 54, 69, 32], 5, 74),
        ([46, 30, 38, 9, 65, 23], 6, 145),
        ([82, 60, 92, 4, 2, 13, 15], 7, 129),
        ([77, 84, 26, 34, 17, 56, 76, 3], 8, 279),
        ([72, 49, 39, 50, 68, 35, 75, 94, 56], 9, 435),
        ([4, 2, 2, 4, 1, 2, 2, 4, 2, 1], 10, 21),
        ([4], 1, 0),
        ([3, 1], 2, 0),
        ([1, 2, 1], 3, 1),
        ([2, 3, 1, 2], 4, 4),
        ([2, 6, 2, 1, 2], 5, 6),
        ([1, 7, 3, 1, 6, 2], 6, 12),
        ([2, 1, 2, 2, 2, 2, 2], 7, 10),
        ([3, 4, 3, 1, 1, 3, 4, 1], 8, 15),
        ([4, 5, 2, 2, 3, 1, 3, 3, 5], 9, 23)
    ]

    passed = 0
    failed = 0

    for i, (arr_vals, n_val, expected) in enumerate(test_cases):
        cocotb.log.info(f"Running test case {i+1}: n={n_val}, arr={arr_vals}")
        
        # Calculate expected using pure Python for safety
        calc_exp = calculate_score(arr_vals, n_val)
        if calc_exp != expected:
             cocotb.log.warning(f"Test case mismatch: Python calc {calc_exp} vs provided {expected}. Using Python calc.")
             expected = calc_exp

        await reset_dut(dut)

        # Set inputs
        dut.n.value = n_val
        dut.start.value = 1
        
        # Set array elements (max 16)
        # Check if it's a packed array or individual signals
        if has_signal(dut, 'arr'):
             # Check if it's an array of signals
             try:
                 dut.arr[0].value
                 is_arr_signal = True
             except (AttributeError, TypeError):
                 is_arr_signal = False
             
             if is_arr_signal:
                 for idx in range(16):
                     if idx < n_val:
                         dut.arr[idx].value = clamp_to_width(arr_vals[idx], 16)
                     else:
                         dut.arr[idx].value = 0
             else:
                 # Packed value
                 val = 0
                 for idx in range(n_val):
                     val |= (clamp_to_width(arr_vals[idx], 16) << (idx * 16))
                 dut.arr.value = val
        elif has_signal(dut, 'arr_0'):
             # Individual signals like arr_0, arr_1...
             for idx in range(16):
                 if idx < n_val:
                     getattr(dut, f'arr_{idx}').value = clamp_to_width(arr_vals[idx], 16)
                 else:
                     getattr(dut, f'arr_{idx}').value = 0
        
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        try:
            await wait_for_done(dut)
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"Test {i+1} PASSED: {result}")
            
        except TestFailure as e:
            cocotb.log.error(f"Test {i+1} FAILED: {e}")
            failed += 1

    if failed > 0:
        raise TestFailure(f"{failed}/{passed+failed} tests failed")
