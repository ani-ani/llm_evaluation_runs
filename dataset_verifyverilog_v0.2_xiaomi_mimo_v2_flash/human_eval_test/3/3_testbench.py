import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_below_zero(dut):
    """Test that bank_account_checker correctly detects when balance goes below zero"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_in.value = 0
    dut.operation.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    print("
Test 1: Empty operations - should be False")
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    dut.valid_in.value = 0  # No operations
    await RisingEdge(dut.clk)
    assert dut.balance_below_zero.value == 0, f"Expected 0 for empty operations, got {dut.balance_below_zero.value}"
    print("PASS: Empty operations handled correctly")
    
    # Wait for DONE state
    await RisingEdge(dut.clk)
    
    print("
Test 2: [1, 2, -3, 1, 2, -3] - should be False")
    operations = [1, 2, -3, 1, 2, -3]
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for op in operations:
        dut.valid_in.value = 1
        dut.operation.value = op
        await RisingEdge(dut.clk)
    
    # End of operations
    dut.valid_in.value = 0
    await RisingEdge(dut.clk)
    assert dut.balance_below_zero.value == 0, f"Expected 0, got {dut.balance_below_zero.value}"
    print("PASS: Sequence never went below zero")
    
    print("
Test 3: [1, 2, -4, 5, 6] - should be True")
    operations = [1, 2, -4, 5, 6]
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for op in operations:
        dut.valid_in.value = 1
        dut.operation.value = op
        await RisingEdge(dut.clk)
        print(f"  After {op}: balance_below_zero = {dut.balance_below_zero.value}")
    
    dut.valid_in.value = 0
    await RisingEdge(dut.clk)
    assert dut.balance_below_zero.value == 1, f"Expected 1, got {dut.balance_below_zero.value}"
    print("PASS: Correctly detected balance went below zero")
    
    print("
Test 4: [1, -1, 2, -2, 5, -5, 4, -4] - should be False")
    operations = [1, -1, 2, -2, 5, -5, 4, -4]
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for op in operations:
        dut.valid_in.value = 1
        dut.operation.value = op
        await RisingEdge(dut.clk)
    
    dut.valid_in.value = 0
    await RisingEdge(dut.clk)
    assert dut.balance_below_zero.value == 0, f"Expected 0, got {dut.balance_below_zero.value}"
    print("PASS: Balance never went below zero")
    
    print("
Test 5: [1, -1, 2, -2, 5, -5, 4, -5] - should be True")
    operations = [1, -1, 2, -2, 5, -5, 4, -5]
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for op in operations:
        dut.valid_in.value = 1
        dut.operation.value = op
        await RisingEdge(dut.clk)
        print(f"  After {op}: balance_below_zero = {dut.balance_below_zero.value}")
    
    dut.valid_in.value = 0
    await RisingEdge(dut.clk)
    assert dut.balance_below_zero.value == 1, f"Expected 1, got {dut.balance_below_zero.value}"
    print("PASS: Correctly detected final withdrawal makes balance negative")
    
    print("
Test 6: [1, -2, 2, -2, 5, -5, 4, -4] - should be True")
    operations = [1, -2, 2, -2, 5, -5, 4, -4]
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for op in operations:
        dut.valid_in.value = 1
        dut.operation.value = op
        await RisingEdge(dut.clk)
    
    dut.valid_in.value = 0
    await RisingEdge(dut.clk)
    assert dut.balance_below_zero.value == 1, f"Expected 1, got {dut.balance_below_zero.value}"
    print("PASS: Early withdrawal correctly detected")
    
    print("
" + "="*50)
    print("All 6 tests passed!")
    print("="*50)
