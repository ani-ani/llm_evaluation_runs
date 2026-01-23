import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_strange_sort_basic(dut):
    """Test basic strange sorting functionality"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.valid_in.value = 0
    dut.start.value = 0
    dut.data_in.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: [1, 2, 3, 4] -> [1, 4, 2, 3]
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Load 4 elements
    test_data = [1, 2, 3, 4]
    for val in test_data:
        dut.data_in.value = val
        dut.valid_in.value = 1
        await RisingEdge(dut.clk)
    dut.valid_in.value = 0
    
    # Wait for sorting and output
    await Timer(200, units='ns')
    
    # Collect outputs
    outputs = []
    for i in range(10):
        if dut.valid_out.value and dut.done.value == 0:
            outputs.append(int(dut.data_out.value))
        await RisingEdge(dut.clk)
    
    expected = [1, 4, 2, 3]
    if outputs[:4] != expected:
        raise TestFailure(f"Expected {expected}, got {outputs[:4]}")

@cocotb.test()
async def test_strange_sort_all_same(dut):
    """Test with all same values"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.valid_in.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Load [5,5,5,5]
    for _ in range(4):
        dut.data_in.value = 5
        dut.valid_in.value = 1
        await RisingEdge(dut.clk)
    dut.valid_in.value = 0
    
    await Timer(200, units='ns')
    
    outputs = []
    for i in range(10):
        if dut.valid_out.value:
            outputs.append(int(dut.data_out.value))
        await RisingEdge(dut.clk)
    
    expected = [5, 5, 5, 5]
    if outputs[:4] != expected:
        raise TestFailure(f"Expected {expected}, got {outputs[:4]}")

@cocotb.test()
async def test_strange_sort_negative(dut):
    """Test with negative numbers"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.valid_in.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Load [0,2,2,2,5,5,-5,-5] -> expected [-5,5,-5,5,0,2,2,2]
    test_data = [0, 2, 2, 2, 5, 5, -5, -5]
    for val in test_data:
        dut.data_in.value = val if val >= 0 else (256 + val)  # Two's complement
        dut.valid_in.value = 1
        await RisingEdge(dut.clk)
    dut.valid_in.value = 0
    
    await Timer(400, units='ns')
    
    outputs = []
    for i in range(15):
        if dut.valid_out.value:
            val = int(dut.data_out.value)
            if val > 127:  # Convert back from two's complement
                val = val - 256
            outputs.append(val)
        await RisingEdge(dut.clk)
    
    expected = [-5, 5, -5, 5, 0, 2, 2, 2]
    if outputs[:8] != expected:
        raise TestFailure(f"Expected {expected}, got {outputs[:8]}")

@cocotb.test()
async def test_strange_sort_8_elements(dut):
    """Test with full 8 elements"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.valid_in.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Load [1,2,3,4,5,6,7,8] -> expected [1,8,2,7,3,6,4,5]
    test_data = [1, 2, 3, 4, 5, 6, 7, 8]
    for val in test_data:
        dut.data_in.value = val
        dut.valid_in.value = 1
        await RisingEdge(dut.clk)
    dut.valid_in.value = 0
    
    await Timer(500, units='ns')
    
    outputs = []
    for i in range(15):
        if dut.valid_out.value:
            outputs.append(int(dut.data_out.value))
        await RisingEdge(dut.clk)
    
    expected = [1, 8, 2, 7, 3, 6, 4, 5]
    if outputs[:8] != expected:
        raise TestFailure(f"Expected {expected}, got {outputs[:8]}")

@cocotb.test()
async def test_strange_sort_single(dut):
    """Test with single element"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.valid_in.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Load [111111] but limit to 8-bit range, use 111
    dut.data_in.value = 111
    dut.valid_in.value = 1
    await RisingEdge(dut.clk)
    dut.valid_in.value = 0
    
    await Timer(200, units='ns')
    
    outputs = []
    for i in range(10):
        if dut.valid_out.value:
            outputs.append(int(dut.data_out.value))
        await RisingEdge(dut.clk)
    
    expected = [111]
    if outputs[:1] != expected:
        raise TestFailure(f"Expected {expected}, got {outputs[:1]}")