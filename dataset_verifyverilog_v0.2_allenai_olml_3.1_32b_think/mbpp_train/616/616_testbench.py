import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_tuple_modulo_basic(dut):
    """Test basic tuple modulo functionality"""
    # Create a 10ns clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Initialize
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.tuple1.value = 0
    dut.tuple2.value = 0
    await Timer(25, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 1: (10,4,5,6) % (5,6,7,5) = (0,4,5,1)
    dut.tuple1[0].value = 10
    dut.tuple1[1].value = 4
    dut.tuple1[2].value = 5
    dut.tuple1[3].value = 6
    dut.tuple2[0].value = 5
    dut.tuple2[1].value = 6
    dut.tuple2[2].value = 7
    dut.tuple2[3].value = 5
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (expected 16 cycles)
    for _ in range(20):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Done signal not asserted after 20 cycles")
    
    # Check results
    assert dut.result[0].value == 0, f"Expected result[0]=0, got {dut.result[0].value}"
    assert dut.result[1].value == 4, f"Expected result[1]=4, got {dut.result[1].value}"
    assert dut.result[2].value == 5, f"Expected result[2]=5, got {dut.result[2].value}"
    assert dut.result[3].value == 1, f"Expected result[3]=1, got {dut.result[3].value}"
    
    print("Test 1 passed: (10,4,5,6) % (5,6,7,5) = (0,4,5,1)")

@cocotb.test()
async def test_tuple_modulo_test2(dut):
    """Test second test case"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(25, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 2: (11,5,6,7) % (6,7,8,6) = (5,5,6,1)
    dut.tuple1[0].value = 11
    dut.tuple1[1].value = 5
    dut.tuple1[2].value = 6
    dut.tuple1[3].value = 7
    dut.tuple2[0].value = 6
    dut.tuple2[1].value = 7
    dut.tuple2[2].value = 8
    dut.tuple2[3].value = 6
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(20):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Done signal not asserted")
    
    assert dut.result[0].value == 5, f"Expected result[0]=5, got {dut.result[0].value}"
    assert dut.result[1].value == 5, f"Expected result[1]=5, got {dut.result[1].value}"
    assert dut.result[2].value == 6, f"Expected result[2]=6, got {dut.result[2].value}"
    assert dut.result[3].value == 1, f"Expected result[3]=1, got {dut.result[3].value}"
    
    print("Test 2 passed: (11,5,6,7) % (6,7,8,6) = (5,5,6,1)")

@cocotb.test()
async def test_tuple_modulo_test3(dut):
    """Test third test case"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(25, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 3: (12,6,7,8) % (7,8,9,7) = (5,6,7,1)
    dut.tuple1[0].value = 12
    dut.tuple1[1].value = 6
    dut.tuple1[2].value = 7
    dut.tuple1[3].value = 8
    dut.tuple2[0].value = 7
    dut.tuple2[1].value = 8
    dut.tuple2[2].value = 9
    dut.tuple2[3].value = 7
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(20):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Done signal not asserted")
    
    assert dut.result[0].value == 5, f"Expected result[0]=5, got {dut.result[0].value}"
    assert dut.result[1].value == 6, f"Expected result[1]=6, got {dut.result[1].value}"
    assert dut.result[2].value == 7, f"Expected result[2]=7, got {dut.result[2].value}"
    assert dut.result[3].value == 1, f"Expected result[3]=1, got {dut.result[3].value}"
    
    print("Test 3 passed: (12,6,7,8) % (7,8,9,7) = (5,6,7,1)")

@cocotb.test()
async def test_tuple_modulo_edge_cases(dut):
    """Test edge cases"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(25, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Edge case: dividend < divisor, dividend == divisor, and others
    # (1, 5, 255, 100) % (10, 5, 1, 50) = (1, 0, 0, 0)
    dut.tuple1[0].value = 1
    dut.tuple1[1].value = 5
    dut.tuple1[2].value = 255
    dut.tuple1[3].value = 100
    dut.tuple2[0].value = 10
    dut.tuple2[1].value = 5
    dut.tuple2[2].value = 1
    dut.tuple2[3].value = 50
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(50):  # May need more cycles for large modulo
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Done signal not asserted for edge cases")
    
    assert dut.result[0].value == 1, f"Expected result[0]=1, got {dut.result[0].value}"
    assert dut.result[1].value == 0, f"Expected result[1]=0, got {dut.result[1].value}"
    assert dut.result[2].value == 0, f"Expected result[2]=0, got {dut.result[2].value}"
    assert dut.result[3].value == 0, f"Expected result[3]=0, got {dut.result[3].value}"
    
    print("Edge cases passed")

@cocotb.test()
async def test_tuple_modulo_zero_dividend(dut):
    """Test with zero dividends"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(25, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # (0, 0, 0, 0) % (5, 6, 7, 8) = (0, 0, 0, 0)
    dut.tuple1[0].value = 0
    dut.tuple1[1].value = 0
    dut.tuple1[2].value = 0
    dut.tuple1[3].value = 0
    dut.tuple2[0].value = 5
    dut.tuple2[1].value = 6
    dut.tuple2[2].value = 7
    dut.tuple2[3].value = 8
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(20):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Done signal not asserted")
    
    assert dut.result[0].value == 0
    assert dut.result[1].value == 0
    assert dut.result[2].value == 0
    assert dut.result[3].value == 0
    
    print("Zero dividend test passed")
