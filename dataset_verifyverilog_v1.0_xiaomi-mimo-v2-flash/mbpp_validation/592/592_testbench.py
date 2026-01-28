import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helper functions
def is_value_defined(v):
    try:
        int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name); return True
    except AttributeError: return False

# Constants
DATA_WIDTH = 8
RESULT_WIDTH = 16
CLK_NS = 10
MAX_CYCLES = 1000

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_sum_of_product(dut):
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational test - just apply inputs and wait
        await Timer(100, units='ns')

    # Define test cases: (n, expected_result)
    test_cases = [
        (1, 1),   # sum_Of_product(1)
        (3, 15),  # sum_Of_product(3)
        (4, 56)   # sum_Of_product(4)
    ]
    
    passed = 0
    failed = 0

    for n_val, expected in test_cases:
        cocotb.log.info(f"Running test: n={n_val}, expected={expected}")
        
        try:
            # Apply input n
            if has_signal(dut, 'n'):
                dut.n.value = clamp_to_width(n_val, 4)
            
            # Trigger computation
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut)
                
                # Check result
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result signal undefined")
                    
                result_val = int(dut.result.value)
                if result_val != expected:
                    raise TestFailure(f"Expected {expected}, got {result_val}")
            else:
                # Combinational fallback
                await Timer(100, units='ns')
                if has_signal(dut, 'result'):
                     result_val = int(dut.result.value)
                     if result_val != expected:
                        raise TestFailure(f"Expected {expected}, got {result_val}")
            
            passed += 1
            cocotb.log.info(f"PASS: n={n_val} -> {expected}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: n={n_val}: {e}")
            failed += 1
            
        # Reset between tests
        if has_signal(dut, 'rst_n'):
            await reset_dut(dut)

    if failed > 0:
        raise TestFailure(f"{failed} out of {passed + failed} tests failed")