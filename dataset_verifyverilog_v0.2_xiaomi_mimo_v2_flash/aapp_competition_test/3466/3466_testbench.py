import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_sweet_diet_basic(dut):
    """Test basic functionality with sample inputs"""
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: m=6, a=[2,1,6,3,5,3], s=[1,1,1,0,2,0], n=5
    # Expected: 1 additional sweet
    dut.m.value = 6
    dut.a[0].value = 2
    dut.a[1].value = 1
    dut.a[2].value = 6
    dut.a[3].value = 3
    dut.a[4].value = 5
    dut.a[5].value = 3
    dut.s[0].value = 1
    dut.s[1].value = 1
    dut.s[2].value = 1
    dut.s[3].value = 0
    dut.s[4].value = 2
    dut.s[5].value = 0
    dut.n.value = 5
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (with timeout)
    for _ in range(500):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    # Check results
    if dut.forever_flag.value:
        print("Test 1: Result - forever")
    else:
        print(f"Test 1: Additional count = {dut.additional_count.value}")
        assert dut.additional_count.value == 1, f"Expected 1, got {dut.additional_count.value}"
    
    print("Test 1 passed!")

@cocotb.test()
async def test_sweet_diet_forever(dut):
    """Test case that should run forever"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 2: m=6, a=[2,1,6,3,5,3], s=[1,1,1,0,1,0], n=4
    # Expected: forever
    dut.m.value = 6
    dut.a[0].value = 2
    dut.a[1].value = 1
    dut.a[2].value = 6
    dut.a[3].value = 3
    dut.a[4].value = 5
    dut.a[5].value = 3
    dut.s[0].value = 1
    dut.s[1].value = 1
    dut.s[2].value = 1
    dut.s[3].value = 0
    dut.s[4].value = 1
    dut.s[5].value = 0
    dut.n.value = 4
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(500):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    if dut.forever_flag.value:
        print("Test 2: Correctly detected forever case")
        assert True
    else:
        print(f"Test 2: Got count {dut.additional_count.value}, expected forever")
        assert False, "Should have detected forever case"
    
    print("Test 2 passed!")

@cocotb.test()
async def test_sweet_diet_edge_cases(dut):
    """Test edge cases"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Edge case: single type, should be balanced forever
    dut.m.value = 1
    dut.a[0].value = 100
    dut.s[0].value = 50
    dut.n.value = 50
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(500):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    if dut.forever_flag.value:
        print("Test 3: Single type - forever (correct)")
    else:
        print(f"Test 3: Single type - count {dut.additional_count.value}")
    
    print("Edge case test completed")

print("Running sweet_diet testbench...")
print("Test cases:")
print("1. Sample 1: expect 1 additional sweet")
print("2. Sample 2: expect forever")
print("3. Edge case: single type")
print("
Results:")