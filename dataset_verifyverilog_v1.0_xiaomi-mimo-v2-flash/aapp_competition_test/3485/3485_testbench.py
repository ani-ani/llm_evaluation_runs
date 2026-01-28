import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants
DATA_WIDTH = 32
FRAC_WIDTH = 32
ARRAY_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 5000

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

def clamp_to_width(v, bits):
    # Handle signedness for clamping
    limit = 1 << (bits - 1)
    if v >= limit:
        return limit - 1
    elif v < -limit:
        return -limit
    return v

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return
    raise TestFailure(f"Timeout: Done signal not asserted after {max_cycles} cycles")

# Reference Model (Python)
def calculate_max_average(cards, n):
    max_avg = 0.0
    # Iterate over all possible skip segments (i to j-1)
    # i: start index of skip (0 to n)
    # j: end index of skip (i to n)
    for i in range(n + 1):
        for j in range(i, n + 1):
            # Counted cards are indices 0..i-1 and j..n-1
            count = i + (n - j)
            if count == 0:
                current_avg = 0.0
            else:
                s = sum(cards[:i]) + sum(cards[j:])
                current_avg = s / count
            if current_avg > max_avg:
                max_avg = current_avg
    return max_avg

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_stop_counting(dut):
    # Setup Clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational logic simulation
        await Timer(10, units='ns')

    test_cases = [
        [10, 10, -10, -4, 10],
        [-3, -1, -4, -1],
        [5, 7, -10, -4, 3],
        [100, 100, 100],
        [-10, -5, -1]
    ]

    for cards in test_cases:
        n = len(cards)
        
        # Pad input if necessary or just fill up to N
        # HDL expects 16 inputs, we provide valid ones first, rest 0
        for i in range(ARRAY_SIZE):
            val = cards[i] if i < n else 0
            # Access individual signals if array port syntax is not supported directly
            if has_signal(dut, f'cards_{i}'):
                getattr(dut, f'cards_{i}').value = clamp_to_width(val, DATA_WIDTH)
            elif hasattr(dut.cards, '__getitem__'):
                dut.cards[i].value = clamp_to_width(val, DATA_WIDTH)
            
        if has_signal(dut, 'N'):
            dut.N.value = n
        
        # Start
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            await wait_for_done(dut)
        else:
            await Timer(100, units='ns')

        # Read Result
        if not is_value_defined(dut.result_int.value) or not is_value_defined(dut.result_frac.value):
            raise TestFailure("Result signals undefined")
            
        res_int = int(dut.result_int.value)
        res_frac = int(dut.result_frac.value)
        
        # Convert back to float
        # The module computes (avg * 2^32)
        # The integer part is likely the high bits, frac is low bits.
        # Assuming standard fixed point: result = res_int + (res_frac / 2^32)
        # However, if the result is strictly an integer average, frac might be 0.
        # Or if the module outputs a 64-bit value split into int and frac parts:
        # Let's assume the prompt meant `result_int` is the whole number part, 
        # and `result_frac` is the remainder scaled by 2^32.
        
        # Reconstruct value
        # Note: Handling signed 32-bit for int part
        computed_val = res_int + (res_frac / (2**32))
        
        expected_val = calculate_max_average(cards, n)
        
        # Allow small error due to fixed point precision
        error = abs(computed_val - expected_val)
        
        if error > 1e-5:
             # Debug logging
            cocotb.log.info(f"Input: {cards}, Expected: {expected_val:.9f}, Got: {computed_val:.9f}")
            raise TestFailure(f"Value mismatch. Expected {expected_val:.9f}, got {computed_val:.9f}")
        else:
            cocotb.log.info(f"Pass: {cards} -> {computed_val:.9f}")
