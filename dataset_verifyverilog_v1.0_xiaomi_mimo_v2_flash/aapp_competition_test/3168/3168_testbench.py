import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 8
MAX_NODES = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

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
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def pulse_start(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_bst_builder(dut):
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: each is a tuple (input_list, expected_cumulative_list)
    test_cases = [
        ([1, 2, 3, 4], [0, 1, 3, 6]),
        ([3, 2, 4, 1, 5], [0, 1, 2, 4, 6]),
        ([8, 3, 5, 1, 6, 7, 2, 4], [0, 1, 2, 4, 7, 11, 13, 15])
    ]
    
    for test_idx, (input_seq, expected_seq) in enumerate(test_cases):
        cocotb.log.info(f"Test case {test_idx+1}: input {input_seq}")
        
        # Feed each number
        for i, (num, expected) in enumerate(zip(input_seq, expected_seq)):
            # Set data_in
            dut.data_in.value = num
            
            # Pulse start
            await pulse_start(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read cumulative_sum
            if not is_value_defined(dut.cumulative_sum.value):
                raise TestFailure(f"cumulative_sum is undefined")
            
            actual = int(dut.cumulative_sum.value)
            
            if actual != expected:
                raise TestFailure(f"Insertion {i+1}: expected cumulative_sum={expected}, got {actual}")
            
            cocotb.log.info(f"  Insertion {i+1}: cumulative_sum={actual} [PASS]")
        
        # Reset for next test case
        await reset_dut(dut)
    
    cocotb.log.info("All tests passed")