import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import random

@cocotb.test()
async def test_coke_mix_basic(dut):
    """Test basic Coke mixing cases"""
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    dut.k.value = 0
    dut.types_data.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: n=400, types=[100, 300, 450, 500] -> Expected 2
    # We simplify: types_data has 4-bit fields. Let's use 4 types
    # 100 = 0x64, 300 = 0x12C (truncate to 4 bits = 12 = 0xC)
    # 450 = 0x1C2 (truncate = 2 = 0x2), 500 = 0x1F4 (truncate = 4 = 0x4)
    # Since we can only fit 4 bits, values are modulo 16
    # Let's use simpler test cases that fit in 4 bits
    
    # Adapted Test: n=8, types=[4, 12] -> 4 + 12 = 16, avg 8, 1+1=2 liters
    dut.n.value = 8
    dut.k.value = 2
    dut.types_data.value = (12 << 4) | 4  # types = [4, 12]
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done (max 200 cycles)
    cycles = 0
    while not dut.done.value and cycles < 300:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if dut.done.value:
        result = int(dut.result.value)
        print(f"Test 1: Result = {result}, Expected = 2")
        if result != 2:
            raise TestFailure(f"Expected 2, got {result}")
    else:
        raise TestFailure("Did not complete in time")
    
    # Reset for next test
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 2: n=6, types=[4, 5] -> Need 1*4 + 2*5 = 14, avg 4.66 (wrong)
    # Let's try: n=6, types=[2, 10] -> 2*2 + 1*10 = 14/3 = 4.66
    # How about: n=10, types=[5, 15] -> (5+15)/2 = 10, result 2
    dut.n.value = 10
    dut.k.value = 2
    dut.types_data.value = (15 << 4) | 5
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while not dut.done.value and cycles < 300:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if dut.done.value:
        result = int(dut.result.value)
        print(f"Test 2: Result = {result}, Expected = 2")
        if result != 2:
            raise TestFailure(f"Expected 2, got {result}")
    else:
        raise TestFailure("Did not complete in time")
    
    # Reset
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 3: n=5, types=[10] -> 10 alone cannot make 5 (impossible)
    # Should return max value (1023)
    dut.n.value = 5
    dut.k.value = 1
    dut.types_data.value = 10
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while not dut.done.value and cycles < 300:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if dut.done.value:
        result = int(dut.result.value)
        print(f"Test 3: Result = {result}, Expected = 1023 (impossible)")
        if result != 1023:
            raise TestFailure(f"Expected 1023, got {result}")
    else:
        raise TestFailure("Did not complete in time")
    
    # Reset
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 4: n=0, types=[0, 5] -> Can use type 0 (0 concentration), 1 liter
    dut.n.value = 0
    dut.k.value = 2
    dut.types_data.value = (5 << 4) | 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while not dut.done.value and cycles < 300:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if dut.done.value:
        result = int(dut.result.value)
        print(f"Test 4: Result = {result}, Expected = 1")
        if result != 1:
            raise TestFailure(f"Expected 1, got {result}")
    else:
        raise TestFailure("Did not complete in time")
    
    # Reset
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 5: n=7, types=[3, 11] -> (3+11)/2 = 7, 2 liters
    dut.n.value = 7
    dut.k.value = 2
    dut.types_data.value = (11 << 4) | 3
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while not dut.done.value and cycles < 300:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if dut.done.value:
        result = int(dut.result.value)
        print(f"Test 5: Result = {result}, Expected = 2")
        if result != 2:
            raise TestFailure(f"Expected 2, got {result}")
    else:
        raise TestFailure("Did not complete in time")
    
    print("All tests passed!")
