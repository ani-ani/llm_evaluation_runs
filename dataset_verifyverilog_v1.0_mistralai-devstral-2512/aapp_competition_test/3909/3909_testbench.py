import cocotb
from cocotb.triggers import Timer, RisingEdge, Join
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants
CLK_NS = 10
MAX_CYCLES = 200  # Should be enough for ~40 iterations
DATA_WIDTH = 64

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
    # Handle negative values if needed, though problem uses unsigned
    mask = (1 << bits) - 1
    return v & mask

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

async def compute_expected(n):
    # Python reference implementation
    k = 1
    while n % k == 0:
        k *= 3
    # ceil(n/k) = (n + k - 1) // k
    return (n + k - 1) // k

@cocotb.test(timeout_time=5, timeout_unit="ms")
async def test_gerald(dut):
    # Setup clock
    clock = Clock(dut.clk, CLK_NS, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (n, expected_result)
    # Inputs from problem description and known outputs
    test_cases = [
        (1, 1),
        (4, 2),
        (3, 1),
        (8, 3),
        (10, 4),
        (243, 1), # 3^5
        (108, 2),
        (2, 1),
        (9, 1)
    ]
    
    for i, (n_in, exp_out) in enumerate(test_cases):
        cocotb.log.info(f"Test case {i+1}: n={n_in}")
        
        # Drive inputs
        dut.n.value = n_in
        dut.start.value = 1
        
        # Wait for rising edge to capture start
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        try:
            await wait_for_done(dut, max_cycles=MAX_CYCLES)
        except TestFailure as e:
            cocotb.log.error(f"Test {i+1} failed: {e}")
            raise
            
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result signal is undefined for n={n_in}")
            
        result = int(dut.result.value)
        
        if result != exp_out:
            raise TestFailure(f"Mismatch for n={n_in}. Expected {exp_out}, got {result}")
        
        cocotb.log.info(f"PASS: n={n_in}, result={result}")
        
        # Small delay between tests
        await Timer(10, units='ns')
        
        # Prepare for next test (ensure ready state)
        await RisingEdge(dut.clk)

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_large_numbers(dut):
    clock = Clock(dut.clk, CLK_NS, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    # Large inputs from the test set
    large_cases = [
        (100000000000000000, 33333333333333334),
        (99999999999999999, 3703703703703704),
        (81, 1), # 3^4
        (72900000000000, 33333333334) # 3^14 * 1000
    ]

    for i, (n_in, exp_out) in enumerate(large_cases):
        cocotb.log.info(f"Large Test {i+1}: n={n_in}")
        dut.n.value = n_in
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        try:
            await wait_for_done(dut, max_cycles=500) # Larger margin for big numbers
        except TestFailure as e:
            cocotb.log.error(f"Large test {i+1} failed: {e}")
            raise
            
        result = int(dut.result.value)
        if result != exp_out:
             raise TestFailure(f"Large mismatch for n={n_in}. Expected {exp_out}, got {result}")
        
        cocotb.log.info(f"PASS: n={n_in}, result={result}")
        await Timer(10, units='ns')
        await RisingEdge(dut.clk)