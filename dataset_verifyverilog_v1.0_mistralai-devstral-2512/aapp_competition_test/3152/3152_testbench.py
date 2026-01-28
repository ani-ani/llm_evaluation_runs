import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Mandatory Helpers
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

def get_val(dut, name):
    try: return int(getattr(dut, name).value)
    except: return 0

async def wait_for_done(dut, max_cycles=5000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# Python Calculation Reference (Modulo 1e9)
def python_calculate(arr):
    MOD = 1000000000
    n = len(arr)
    total = 0
    for i in range(n):
        current_min = arr[i]
        current_max = arr[i]
        for j in range(i, n):
            val = arr[j]
            if val < current_min: current_min = val
            if val > current_max: current_max = val
            length = j - i + 1
            cost = (current_min * current_max * length)
            total = (total + cost) % MOD
    return total

# Array Helper
def write_array(dut, arr_data):
    N = 16
    for i in range(N):
        val = arr_data[i] if i < len(arr_data) else 0
        dut.arr[i].value = clamp_to_width(val, 32)

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_subsequence_sum(dut):
    # Setup Clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define Test Cases (Pad to 16 elements)
    test_cases = [
        ([1, 3], 16),
        ([2, 4, 1, 4], 109),
        ([8, 1, 3, 9, 7, 4], 1042)
    ]
    
    for i, (input_vals, expected) in enumerate(test_cases):
        cocotb.log.info(f"Running Test Case {i+1}")
        
        # Write inputs
        write_array(dut, input_vals)
        
        # Start signal
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure("Result signal is undefined")
            
        result = int(dut.result.value)
        
        # Verify
        if result != expected:
            raise TestFailure(f"Test {i+1} Failed: Expected {expected}, Got {result}")
        else:
            cocotb.log.info(f"Test {i+1} Passed: Result {result}")
        
        # Small delay between tests
        await Timer(100, units='ns')

    cocotb.log.info("All tests passed!")