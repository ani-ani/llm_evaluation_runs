import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure
import random

@cocotb.test()
async def test_binary_string_cost(dut):
    """Test binary string cost calculation"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Initialize
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_in.value = 0
    dut.valid_in.value = 0
    dut.str_len.value = 0
    
    await Timer(50, units="ns")
    dut.rst_n.value = 1
    await Timer(20, units="ns")
    
    # Test cases: (string, expected_cost)
    # x=10, y=1 in this test
    # Formula: if x <= y: (groups-1)*x + y else: groups*y
    # Since x=10 > y=1, use: groups * y
    
    test_cases = [
        ("0000", 1),      # 1 group, cost = 1*1 = 1
        ("0100", 2),      # 2 groups, cost = 2*1 = 2
        ("0101", 2),      # 2 groups, cost = 2*1 = 2
        ("1111", 0),      # 0 groups, cost = 0
        ("1010", 2),      # 2 groups, cost = 2*1 = 2
        ("0001", 1),      # 1 group, cost = 1*1 = 1
        ("1000", 1),      # 1 group, cost = 1*1 = 1
    ]
    
    for test_str, expected in test_cases:
        dut.str_len.value = len(test_str)
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Feed string characters
        for char in test_str:
            dut.char_in.value = ord(char) - ord('0')
            dut.valid_in.value = 1
            await RisingEdge(dut.clk)
        
        dut.valid_in.value = 0
        
        # Wait for computation
        for _ in range(15):
            await RisingEdge(dut.clk)
            if dut.done.value:
                break
        
        if not dut.done.value:
            raise TestFailure(f"Done not asserted for string '{test_str}'")
        
        result = int(dut.result.value)
        if result != expected:
            raise TestFailure(f"String '{test_str}': expected {expected}, got {result}")
        
        print(f"Test '{test_str}': PASSED (cost={result})")
    
    print(f"All tests passed!")
