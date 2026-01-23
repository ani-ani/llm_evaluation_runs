import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

def float_to_q16_16(val):
    return int(val * 65536)

def q16_16_to_float(val):
    return val / 65536.0

@cocotb.test()
async def test_binary_town_voting(dut):
    """Test the Binary Town Voting logic"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.voter_valid.value = 0
    dut.voter_prob.value = 0
    dut.voter_ballot.value = 0
    dut.voter_id.value = 0
    
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: k=2 (4 states), v=2 (1 other voter)
    # Other voter: p=0.5, b=1
    # Expected Output: 2 (based on problem description)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Feed voter 0
    dut.voter_valid.value = 1
    dut.voter_id.value = 0
    dut.voter_prob.value = float_to_q16_16(0.5)
    dut.voter_ballot.value = 1
    await RisingEdge(dut.clk)
    
    # Signal end of input for remaining slots (simulate up to 9 voters)
    # We need to feed valid=0 for the rest of the defined max voters (e.g. 9)
    # The module should stop consuming when internal counter hits max or we send done signal conceptually.
    # However, in this IO interface, we just cycle through ID 0..8.
    for i in range(1, 9):
        dut.voter_valid.value = 0
        dut.voter_id.value = i
        await RisingEdge(dut.clk)
        
    # Wait for DONE
    timeout = 0
    while not dut.done.value and timeout < 500:
        await RisingEdge(dut.clk)
        timeout += 1
        
    if not dut.done.value:
        raise TestFailure("Module did not assert done in time")
        
    result = int(dut.optimal_b_self.value)
    print(f"Test 1: Result={result}, Expected=2")
    if result != 2:
        raise TestFailure(f"Expected 2, got {result}")
        
    # Test Case 2: k=4, v=3
    # Voter 1: p=1.0, b=11
    # Voter 2: p=0.4, b=1
    # Expected Output: 3
    
    # Reset
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Feed Voter 0 (p=1.0, b=11)
    dut.voter_valid.value = 1
    dut.voter_id.value = 0
    dut.voter_prob.value = float_to_q16_16(1.0)
    dut.voter_ballot.value = 11
    await RisingEdge(dut.clk)
    
    # Feed Voter 1 (p=0.4, b=1)
    dut.voter_id.value = 1
    dut.voter_prob.value = float_to_q16_16(0.4)
    dut.voter_ballot.value = 1
    await RisingEdge(dut.clk)
    
    # Feed invalids for remaining
    for i in range(2, 9):
        dut.voter_valid.value = 0
        dut.voter_id.value = i
        await RisingEdge(dut.clk)
        
    timeout = 0
    while not dut.done.value and timeout < 500:
        await RisingEdge(dut.clk)
        timeout += 1
        
    if not dut.done.value:
        raise TestFailure("Module did not assert done in time")
        
    result = int(dut.optimal_b_self.value)
    print(f"Test 2: Result={result}, Expected=3")
    if result != 3:
        raise TestFailure(f"Expected 3, got {result}")
