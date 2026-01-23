import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random
from math import gcd

# Configuration
DATA_WIDTH = 8
N = 4
MAX_ENTRIES = N * N
CLK_PERIOD_NS = 10
MAX_CYCLES = 5000

# Helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_gcd_table_solver(dut):
    """Test GCD table solver with random and example cases"""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Initialize
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.data_valid.value = 0
    dut.data_in.value = 0
    
    # Reset
    for _ in range(3):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        ([4, 3, 6, 2], [2, 1, 2, 3, 4, 3, 2, 6, 1, 1, 2, 2, 1, 2, 3, 2]),
        ([42], [42]),
        ([1, 1], [1, 1, 1, 1]),
        ([5, 3], [1, 1, 1, 15]),
        ([8, 12, 4], [4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4]),
    ]
    
    for test_idx, (original, table) in enumerate(test_cases):
        dut._log.info(f"Test {test_idx+1}: Original={original}")
        
        # Generate shuffled table
        test_table = table.copy()
        random.shuffle(test_table)
        
        # Start pulse
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Feed inputs
        for num in test_table:
            await RisingEdge(dut.clk)
            dut.data_in.value = clamp_to_width(num, DATA_WIDTH)
            dut.data_valid.value = 1
            await RisingEdge(dut.clk)
            dut.data_valid.value = 0
        
        # Wait for results
        results = []
        cycles = 0
        done = False
        
        while not done and cycles < MAX_CYCLES:
            await RisingEdge(dut.clk)
            cycles += 1
            
            if is_value_defined(dut.result_valid.value) and int(dut.result_valid.value) == 1:
                if is_value_defined(dut.result.value):
                    results.append(int(dut.result.value))
                    dut._log.info(f"Result: {int(dut.result.value)}")
            
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done = True
                dut._log.info("Done signal received")
        
        if not done:
            raise TestFailure(f"Timeout after {MAX_CYCLES} cycles")
        
        # Verify results
        if len(results) != len(original):
            raise TestFailure(f"Expected {len(original)} results, got {len(results)}")
        
        if sorted(original) != sorted(results):
            raise TestFailure(f"Result mismatch: expected {sorted(original)}, got {sorted(results)}")
        
        dut._log.info(f"Test {test_idx+1} PASSED")
        
        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    dut._log.info("All tests passed!")