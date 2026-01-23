import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure
import random

@cocotb.test()
async def test_dict_sorter_basic(dut):
    """Test basic dictionary sorting functionality"""
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Initialize
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.key_0.value = 0
    dut.key_1.value = 0
    dut.key_2.value = 0
    dut.key_3.value = 0
    dut.key_4.value = 0
    dut.key_5.value = 0
    dut.key_6.value = 0
    dut.key_7.value = 0
    dut.value_0.value = 0
    dut.value_1.value = 0
    dut.value_2.value = 0
    dut.value_3.value = 0
    dut.value_4.value = 0
    dut.value_5.value = 0
    dut.value_6.value = 0
    dut.value_7.value = 0
    
    await Timer(20, units='ns')
    await FallingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 1: {'Math':81, 'Physics':83, 'Chemistry':87}
    # M=77, P=80, C=67
    dut.key_0.value = 67  # 'C'
    dut.value_0.value = 87
    dut.key_1.value = 80  # 'P'
    dut.value_1.value = 83
    dut.key_2.value = 77  # 'M'
    dut.value_2.value = 81
    dut.key_3.value = 0   # empty
    dut.value_3.value = 0
    dut.key_4.value = 0
    dut.value_4.value = 0
    dut.key_5.value = 0
    dut.value_5.value = 0
    dut.key_6.value = 0
    dut.value_6.value = 0
    dut.key_7.value = 0
    dut.value_7.value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done (28 cycles + 1 for output)
    for _ in range(30):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure(f"Done not asserted after 30 cycles")
    
    # Check outputs - should be sorted descending
    assert dut.out_value_0.value == 87, f"Expected 87, got {dut.out_value_0.value}"
    assert dut.out_value_1.value == 83, f"Expected 83, got {dut.out_value_1.value}"
    assert dut.out_value_2.value == 81, f"Expected 81, got {dut.out_value_2.value}"
    assert dut.out_key_0.value == 67, f"Expected C(67), got {dut.out_key_0.value}"
    assert dut.out_key_1.value == 80, f"Expected P(80), got {dut.out_key_1.value}"
    assert dut.out_key_2.value == 77, f"Expected M(77), got {dut.out_key_2.value}"
    
    print(f"Test 1 passed: {dut.out_value_0.value}, {dut.out_value_1.value}, {dut.out_value_2.value}")
    await RisingEdge(dut.clk)
    
    # Test 2: {'Math':400, 'Physics':300, 'Chemistry':250}
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.key_0.value = 77  # 'M'
    dut.value_0.value = 400
    dut.key_1.value = 80  # 'P'
    dut.value_1.value = 300
    dut.key_2.value = 67  # 'C'
    dut.value_2.value = 250
    dut.key_3.value = 0
    dut.value_3.value = 0
    dut.key_4.value = 0
    dut.value_4.value = 0
    dut.key_5.value = 0
    dut.value_5.value = 0
    dut.key_6.value = 0
    dut.value_6.value = 0
    dut.key_7.value = 0
    dut.value_7.value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(30):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.out_value_0.value == 400, f"Expected 400, got {dut.out_value_0.value}"
    assert dut.out_value_1.value == 300, f"Expected 300, got {dut.out_value_1.value}"
    assert dut.out_value_2.value == 250, f"Expected 250, got {dut.out_value_2.value}"
    assert dut.out_key_0.value == 77, f"Expected M(77), got {dut.out_key_0.value}"
    print(f"Test 2 passed: {dut.out_value_0.value}, {dut.out_value_1.value}, {dut.out_value_2.value}")
    await RisingEdge(dut.clk)
    
    # Test 3: {'Math':900, 'Physics':1000, 'Chemistry':1250}
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.key_0.value = 77  # 'M'
    dut.value_0.value = 900
    dut.key_1.value = 80  # 'P'
    dut.value_1.value = 1000
    dut.key_2.value = 67  # 'C'
    dut.value_2.value = 1250
    dut.key_3.value = 0
    dut.value_3.value = 0
    dut.key_4.value = 0
    dut.value_4.value = 0
    dut.key_5.value = 0
    dut.value_5.value = 0
    dut.key_6.value = 0
    dut.value_6.value = 0
    dut.key_7.value = 0
    dut.value_7.value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(30):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.out_value_0.value == 1250, f"Expected 1250, got {dut.out_value_0.value}"
    assert dut.out_value_1.value == 1000, f"Expected 1000, got {dut.out_value_1.value}"
    assert dut.out_value_2.value == 900, f"Expected 900, got {dut.out_value_2.value}"
    assert dut.out_key_0.value == 67, f"Expected C(67), got {dut.out_key_0.value}"
    print(f"Test 3 passed: {dut.out_value_0.value}, {dut.out_value_1.value}, {dut.out_value_2.value}")
    
    print("All 3 tests passed!")