import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_swap_list(dut):
    """Test swapping first and last elements in fixed-size array"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.size.value = 0
    for i in range(8):
        dut.arr_in[i].value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    print("
=== Testing swap_list module ===")
    
    # Test 1: Basic swap with 3 elements
    print("
Test 1: [1,2,3] -> [3,2,1]")
    dut.arr_in[0].value = 1
    dut.arr_in[1].value = 2
    dut.arr_in[2].value = 3
    for i in range(3, 8):
        dut.arr_in[i].value = 0
    dut.size.value = 3
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    assert dut.done.value == 1, "Done should be high"
    result = [int(dut.arr_out[i].value) for i in range(8)]
    print(f"Result: {result[:3]}...")
    assert result[0] == 3, f"Expected arr_out[0]=3, got {result[0]}"
    assert result[1] == 2, f"Expected arr_out[1]=2, got {result[1]}"
    assert result[2] == 1, f"Expected arr_out[2]=1, got {result[2]}"
    print("✓ Test 1 passed")
    await RisingEdge(dut.clk)
    
    # Test 2: 5 elements with duplicate
    print("
Test 2: [1,2,3,4,4] -> [4,2,3,4,1]")
    dut.arr_in[0].value = 1
    dut.arr_in[1].value = 2
    dut.arr_in[2].value = 3
    dut.arr_in[3].value = 4
    dut.arr_in[4].value = 4
    for i in range(5, 8):
        dut.arr_in[i].value = 0
    dut.size.value = 5
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    result = [int(dut.arr_out[i].value) for i in range(8)]
    print(f"Result: {result[:5]}...")
    assert result[0] == 4, f"Expected arr_out[0]=4, got {result[0]}"
    assert result[1] == 2, f"Expected arr_out[1]=2, got {result[1]}"
    assert result[2] == 3, f"Expected arr_out[2]=3, got {result[2]}"
    assert result[3] == 4, f"Expected arr_out[3]=4, got {result[3]}"
    assert result[4] == 1, f"Expected arr_out[4]=1, got {result[4]}"
    print("✓ Test 2 passed")
    await RisingEdge(dut.clk)
    
    # Test 3: Another 3-element case
    print("
Test 3: [4,5,6] -> [6,5,4]")
    dut.arr_in[0].value = 4
    dut.arr_in[1].value = 5
    dut.arr_in[2].value = 6
    for i in range(3, 8):
        dut.arr_in[i].value = 0
    dut.size.value = 3
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    result = [int(dut.arr_out[i].value) for i in range(8)]
    print(f"Result: {result[:3]}...")
    assert result[0] == 6, f"Expected arr_out[0]=6, got {result[0]}"
    assert result[1] == 5, f"Expected arr_out[1]=5, got {result[1]}"
    assert result[2] == 4, f"Expected arr_out[2]=4, got {result[2]}"
    print("✓ Test 3 passed")
    await RisingEdge(dut.clk)
    
    # Edge case: Single element (size=1)
    print("
Edge case: size=1, [5] -> [5]")
    dut.arr_in[0].value = 5
    for i in range(1, 8):
        dut.arr_in[i].value = 0
    dut.size.value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    result = [int(dut.arr_out[i].value) for i in range(8)]
    print(f"Result: {result[:1]}...")
    assert result[0] == 5, f"Expected arr_out[0]=5, got {result[0]}"
    print("✓ Edge case passed")
    await RisingEdge(dut.clk)
    
    # Edge case: Two elements (size=2)
    print("
Edge case: size=2, [7,8] -> [8,7]")
    dut.arr_in[0].value = 7
    dut.arr_in[1].value = 8
    for i in range(2, 8):
        dut.arr_in[i].value = 0
    dut.size.value = 2
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    result = [int(dut.arr_out[i].value) for i in range(8)]
    print(f"Result: {result[:2]}...")
    assert result[0] == 8, f"Expected arr_out[0]=8, got {result[0]}"
    assert result[1] == 7, f"Expected arr_out[1]=7, got {result[1]}"
    print("✓ Edge case passed")
    await RisingEdge(dut.clk)
    
    print("
=== All tests passed! ===")