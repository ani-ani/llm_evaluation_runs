import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_last_digit_basic(dut):
    """Test basic last digit extraction"""
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.number.value = 0
    await Timer(25, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: last_Digit(123) = 3
    dut.number.value = 123
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (35 cycles)
    for _ in range(35):
        await RisingEdge(dut.clk)
    
    if dut.done.value != 1:
        raise TestFailure(f"Done not asserted. Got {dut.done.value}")
    if dut.last_digit.value != 3:
        raise TestFailure(f"Expected 3, got {dut.last_digit.value}")
    print(f"Test 1 passed: last_Digit(123) = {dut.last_digit.value}")

@cocotb.test()
async def test_last_digit_tens(dut):
    """Test last digit with tens place"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.number.value = 0
    await Timer(25, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 2: last_Digit(25) = 5
    dut.number.value = 25
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(35):
        await RisingEdge(dut.clk)
    
    if dut.done.value != 1:
        raise TestFailure("Done not asserted")
    if dut.last_digit.value != 5:
        raise TestFailure(f"Expected 5, got {dut.last_digit.value}")
    print(f"Test 2 passed: last_Digit(25) = {dut.last_digit.value}")

@cocotb.test()
async def test_last_digit_zero(dut):
    """Test last digit with zero"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.number.value = 0
    await Timer(25, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 3: last_Digit(30) = 0
    dut.number.value = 30
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(35):
        await RisingEdge(dut.clk)
    
    if dut.done.value != 1:
        raise TestFailure("Done not asserted")
    if dut.last_digit.value != 0:
        raise TestFailure(f"Expected 0, got {dut.last_digit.value}")
    print(f"Test 3 passed: last_Digit(30) = {dut.last_digit.value}")

@cocotb.test()
async def test_last_digit_edge_cases(dut):
    """Test edge cases"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.number.value = 0
    await Timer(25, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test: last_Digit(0) = 0
    dut.number.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    for _ in range(35):
        await RisingEdge(dut.clk)
    if dut.last_digit.value != 0:
        raise TestFailure(f"Expected 0, got {dut.last_digit.value}")
    print(f"Edge test 1 passed: last_Digit(0) = {dut.last_digit.value}")
    
    # Reset for next test
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test: last_Digit(999999999) = 9 (simulate with max 32-bit)
    dut.number.value = 999999999
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    for _ in range(35):
        await RisingEdge(dut.clk)
    if dut.last_digit.value != 9:
        raise TestFailure(f"Expected 9, got {dut.last_digit.value}")
    print(f"Edge test 2 passed: last_Digit(999999999) = {dut.last_digit.value}")
    
    print("All 5 tests passed!")