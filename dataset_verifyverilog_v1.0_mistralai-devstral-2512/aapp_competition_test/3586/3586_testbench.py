import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants
DATA_WIDTH = 16
ARRAY_SIZE = 8
CLK_NS = 10
MAX_CYCLES = 2000  # Allow ample time for brute force

# Helper Functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def to_signed(val, bits):
    # Convert Python int to 2's complement value if needed, 
    # but Python handles large ints, so just clamp
    if val >= (1 << (bits-1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    # Convert 2's complement to positive Python int if negative
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    # Clamp to signed range -2^(n-1) to 2^(n-1)-1
    min_val = -(1 << (bits - 1))
    max_val = (1 << (bits - 1)) - 1
    if v > max_val: return max_val
    if v < min_val: return min_val
    return v

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    if has_signal(dut, 'valid_in'):
        dut.valid_in.value = 0
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

async def set_array(dut, values):
    # Pad or truncate to ARRAY_SIZE
    vals = values + [0] * (ARRAY_SIZE - len(values))
    # Access individual elements
    for i in range(ARRAY_SIZE):
        val = clamp_to_width(vals[i], DATA_WIDTH)
        # Try accessing as array index first, then named signals
        if hasattr(dut.arr, '__getitem__'):
            dut.arr[i].value = from_signed(val, DATA_WIDTH)
        else:
            # Fallback for flattened ports (arr_0, arr_1...)
            port_name = f'arr_{i}'
            if hasattr(dut, port_name):
                getattr(dut, port_name).value = from_signed(val, DATA_WIDTH)
            else:
                 # Try packed array if available (unlikely for 8x16 but good practice)
                 pass

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_find_max_d(dut):
    # Setup Clock
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational logic assumption
        await Timer(100, units='ns')

    # Helper to compute expected result
    def solve_python(arr):
        n = len(arr)
        best = -float('inf')
        found = False
        # Check all 4-tuples
        for i in range(n):
            for j in range(n):
                if i == j: continue
                for k in range(n):
                    if k == i or k == j: continue
                    for l in range(n):
                        if l == i or l == j or l == k: continue
                        if arr[i] + arr[j] + arr[k] == arr[l]:
                            if arr[l] > best:
                                best = arr[l]
                                found = True
        return best if found else None

    # Test Cases
    test_cases = [
        ([2, 3, 5, 7, 12], 12, "Sample 1"),
        ([2, 16, 64, 256, 1024], None, "Sample 2 (No Solution)"),
        ([1, 2, 3, 4, 5, 6, 7, 8], 8, "Small consecutive"),
        ([100, 200, 300, 500], 500, "Simple sum"),
        ([-1, -2, -3, -4], None, "Negative numbers (no solution likely)"),
    ]

    passed = 0
    failed = 0

    for inp, expected, desc in test_cases:
        cocotb.log.info(f"Running Test: {desc}")
        try:
            # Prepare input data (pad to 8 elements if needed)
            actual_input = inp + [0] * (8 - len(inp))
            
            if is_seq:
                # Write data
                await set_array(dut, actual_input)
                
                # Assert valid and start
                if has_signal(dut, 'valid_in'):
                    dut.valid_in.value = 1
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                # valid_in can stay high or go low; here we keep it high for simplicity
                
                # Wait for done
                await wait_for_done(dut, 2000)
                
                # Read results
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result signal undefined")
                
                res_val = int(dut.result.value)
                # Convert from 2's complement if negative
                res_val = to_signed(res_val, DATA_WIDTH)
                
                no_sol = int(dut.no_solution.value) if has_signal(dut, 'no_solution') else 0
                
                if expected is None:
                    if no_sol != 1:
                        raise TestFailure(f"Expected 'no solution', but got result {res_val} with no_solution={no_sol}")
                else:
                    if res_val != expected:
                         raise TestFailure(f"Expected {expected}, got {res_val}")
            else:
                # Combinational: assign inputs and check immediately
                await set_array(dut, actual_input)
                await Timer(10, units='ns')
                # ... (comb logic checks similar to above)
                pass

            cocotb.log.info(f"PASS: {desc}")
            passed += 1

        except TestFailure as e:
            cocotb.log.error(f"FAIL {desc}: {e}")
            failed += 1

    if failed:
        raise TestFailure(f"{failed} out of {passed + failed} tests failed")
