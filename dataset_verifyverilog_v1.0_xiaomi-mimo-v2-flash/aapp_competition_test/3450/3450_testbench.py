import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helpers
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

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    if v < 0:
        return 0
    return min(max_val, v)

# Calculation for verification (Python supports arbitrary precision)
def python_solve(n):
    # Compute n!
    fact = 1
    for i in range(1, n + 1):
        fact *= i
    
    # Remove trailing zeros
    while fact > 0 and fact % 10 == 0:
        fact //= 10
    
    # Get last 3 digits
    return fact % 1000

@cocotb.test(timeout_time=10, timeout_unit='ms')
async def test_factorial_digits(dut):
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: n from 1 to 16 (constrained range for 64-bit limit)
    # Python handles 10000000, but HDL is limited to n=16.
    # We test the upper range of HDL capability.
    test_n_values = [1, 2, 3, 4, 5, 7, 10, 12, 15, 16]
    
    for n_val in test_n_values:
        dut._log.info(f"Testing n={n_val}")
        
        # Drive inputs
        dut.n.value = n_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout_cycles = 100
        done_seen = False
        for _ in range(timeout_cycles):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done_seen = True
                break
        
        if not done_seen:
            raise TestFailure(f"Timeout waiting for done for n={n_val}")
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result undefined for n={n_val}")
            
        hdl_result = int(dut.result.value)
        expected = python_solve(n_val)
        
        dut._log.info(f"n={n_val}: HDL={hdl_result}, Expected={expected}")
        
        if hdl_result != expected:
            raise TestFailure(f"Mismatch for n={n_val}: HDL={hdl_result}, Expected={expected}")
        
        # Wait one cycle before next test
        await RisingEdge(dut.clk)
        
    dut._log.info("All tests passed for n <= 16")