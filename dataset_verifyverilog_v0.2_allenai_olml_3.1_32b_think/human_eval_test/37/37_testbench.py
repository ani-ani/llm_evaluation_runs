import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

@cocotb.test()
async def test_sort_even_basic(dut):
    """Test basic sorting of even indices"""
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Initialize
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.data_in.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: [1, 2, 3] -> [1, 2, 3]
    # Even indices: 0=1, 2=3 (already sorted)
    dut.data_in[0].value = 1
    dut.data_in[1].value = 2
    dut.data_in[2].value = 3
    dut.data_in[3].value = 0
    dut.data_in[4].value = 0
    dut.data_in[5].value = 0
    dut.data_in[6].value = 0
    dut.data_in[7].value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 50
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    else:
        raise TestFailure("Timeout waiting for done")
    
    # Check output
    assert int(dut.data_out[0].value) == 1
    assert int(dut.data_out[1].value) == 2
    assert int(dut.data_out[2].value) == 3
    assert int(dut.data_out[3].value) == 0
    print("Test 1 passed: [1,2,3,0,0,0,0,0] -> [1,2,3,0,0,0,0,0]")

@cocotb.test()
async def test_sort_even_unsorted(dut):
    """Test unsorted even indices"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 2: [5, 6, 3, 4] -> [3, 6, 5, 4]
    # Even indices: 0=5, 2=3 -> sorted: 0=3, 2=5
    # Odd indices: 1=6, 3=4 -> unchanged
    dut.data_in[0].value = 5
    dut.data_in[1].value = 6
    dut.data_in[2].value = 3
    dut.data_in[3].value = 4
    dut.data_in[4].value = 0
    dut.data_in[5].value = 0
    dut.data_in[6].value = 0
    dut.data_in[7].value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 50
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    else:
        raise TestFailure("Timeout waiting for done")
    
    assert int(dut.data_out[0].value) == 3
    assert int(dut.data_out[1].value) == 6
    assert int(dut.data_out[2].value) == 5
    assert int(dut.data_out[3].value) == 4
    print("Test 2 passed: [5,6,3,4,0,0,0,0] -> [3,6,5,4,0,0,0,0]")

@cocotb.test()
async def test_sort_even_full_array(dut):
    """Test with all 8 elements, including negative numbers"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 3: [5, 8, -12, 4, 23, 2, 3, 11]
    # Even indices: 0=5, 2=-12, 4=23, 6=3 -> sorted: -12, 3, 5, 23
    # Odd indices: 1=8, 3=4, 5=2, 7=11 -> unchanged
    dut.data_in[0].value = 5
    dut.data_in[1].value = 8
    dut.data_in[2].value = 244  # -12 in two's complement 8-bit
    dut.data_in[3].value = 4
    dut.data_in[4].value = 23
    dut.data_in[5].value = 2
    dut.data_in[6].value = 3
    dut.data_in[7].value = 11
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 50
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    else:
        raise TestFailure("Timeout waiting for done")
    
    assert int(dut.data_out[0].value) == 244  # -12
    assert int(dut.data_out[1].value) == 8
    assert int(dut.data_out[2].value) == 3
    assert int(dut.data_out[3].value) == 4
    assert int(dut.data_out[4].value) == 5
    assert int(dut.data_out[5].value) == 2
    assert int(dut.data_out[6].value) == 23
    assert int(dut.data_out[7].value) == 11
    print("Test 3 passed: [-12,8,5,4,23,2,3,11] -> [-12,8,3,4,5,2,23,11]")

@cocotb.test()
async def test_sort_even_edge_cases(dut):
    """Test edge cases: all even sorted, already sorted, negative values"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test: all even indices descending: [10,1,8,2,6,3,4,5]
    # Even: 10,8,6,4 -> sorted: 4,6,8,10
    # Odd: 1,2,3,5 -> unchanged
    dut.data_in[0].value = 10
    dut.data_in[1].value = 1
    dut.data_in[2].value = 8
    dut.data_in[3].value = 2
    dut.data_in[4].value = 6
    dut.data_in[5].value = 3
    dut.data_in[6].value = 4
    dut.data_in[7].value = 5
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 50
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    else:
        raise TestFailure("Timeout waiting for done")
    
    assert int(dut.data_out[0].value) == 4
    assert int(dut.data_out[1].value) == 1
    assert int(dut.data_out[2].value) == 6
    assert int(dut.data_out[3].value) == 2
    assert int(dut.data_out[4].value) == 8
    assert int(dut.data_out[5].value) == 3
    assert int(dut.data_out[6].value) == 10
    assert int(dut.data_out[7].value) == 5
    print("Test 4 passed: [10,1,8,2,6,3,4,5] -> [4,1,6,2,8,3,10,5]")
