import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import math

@cocotb.test()
async def test_magic_boxes_basic(dut):
    """Test basic functionality with 2 box types"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_in.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Inputs for test case 1: (k=0, a=3), (k=1, a=5)
    # Expected logic:
    # Type 0: k=0, a=3 -> ceil(log4(3)) = 1 -> p = 0+1 = 1
    # Type 1: k=1, a=5 -> ceil(log4(5)) = 2 -> p = 1+2 = 3
    # Result = 3
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Feed inputs
    # Type 0: k=0, a=3
    dut.valid_in.value = 1
    dut.k_in.value = 0
    dut.a_in.value = 3
    dut.type_index.value = 0
    await RisingEdge(dut.clk)
    
    # Type 1: k=1, a=5
    dut.k_in.value = 1
    dut.a_in.value = 5
    dut.type_index.value = 1
    await RisingEdge(dut.clk)
    
    # Type 2: k=2, a=1 (dummy, should not affect max)
    dut.k_in.value = 2
    dut.a_in.value = 1
    dut.type_index.value = 2
    await RisingEdge(dut.clk)
    
    # Type 3: k=3, a=1 (dummy)
    dut.k_in.value = 3
    dut.a_in.value = 1
    dut.type_index.value = 3
    await RisingEdge(dut.clk)
    
    dut.valid_in.value = 0
    
    # Wait for computation
    for _ in range(30):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
            
    if dut.done.value != 1:
        raise TestFailure("Module did not assert done signal in time")
        
    if int(dut.result.value) != 3:
        raise TestFailure(f"Expected result 3, got {int(dut.result.value)}")

@cocotb.test()
async def test_magic_boxes_case2(dut):
    """Test case 2: (0, 4) -> Result 1"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_in.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Inputs: (0, 4), (0,1), (0,1), (0,1)
    # Type 0: k=0, a=4 -> ceil(log4(4)) = 1 -> p=1
    
    dut.valid_in.value = 1
    dut.k_in.value = 0
    dut.a_in.value = 4
    dut.type_index.value = 0
    await RisingEdge(dut.clk)
    
    dut.k_in.value = 0
    dut.a_in.value = 1
    dut.type_index.value = 1
    await RisingEdge(dut.clk)
    
    dut.k_in.value = 0
    dut.a_in.value = 1
    dut.type_index.value = 2
    await RisingEdge(dut.clk)
    
    dut.k_in.value = 0
    dut.a_in.value = 1
    dut.type_index.value = 3
    await RisingEdge(dut.clk)
    
    dut.valid_in.value = 0
    
    for _ in range(30):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
            
    if dut.done.value != 1:
        raise TestFailure("Module did not assert done signal")
        
    if int(dut.result.value) != 1:
        raise TestFailure(f"Expected result 1, got {int(dut.result.value)}")

@cocotb.test()
async def test_magic_boxes_case3(dut):
    """Test case 3: (1, 10), (2, 2) -> Result 3"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_in.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Inputs:
    # Type 0: k=1, a=10 -> ceil(log4(10)) = 2 -> p = 1+2 = 3
    # Type 1: k=2, a=2 -> ceil(log4(2)) = 1 -> p = 2+1 = 3
    # Max = 3
    
    dut.valid_in.value = 1
    dut.k_in.value = 1
    dut.a_in.value = 10
    dut.type_index.value = 0
    await RisingEdge(dut.clk)
    
    dut.k_in.value = 2
    dut.a_in.value = 2
    dut.type_index.value = 1
    await RisingEdge(dut.clk)
    
    dut.k_in.value = 0
    dut.a_in.value = 1
    dut.type_index.value = 2
    await RisingEdge(dut.clk)
    
    dut.k_in.value = 0
    dut.a_in.value = 1
    dut.type_index.value = 3
    await RisingEdge(dut.clk)
    
    dut.valid_in.value = 0
    
    for _ in range(30):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
            
    if dut.done.value != 1:
        raise TestFailure("Module did not assert done signal")
        
    if int(dut.result.value) != 3:
        raise TestFailure(f"Expected result 3, got {int(dut.result.value)}")

@cocotb.test()
async def test_magic_boxes_max_overflow(dut):
    """Test large inputs to check calculation logic"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_in.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Inputs:
    # Type 0: k=31, a=100 -> ceil(log4(100)) = 3 (since 4^3=64 < 100 <= 256=4^4? No 4^3=64, 4^4=256. Wait. 100 > 64, so ceil is 4?)
    # Wait, 4^1=4, 4^2=16, 4^3=64, 4^4=256.
    # 1 <= 100. 4 < 100. 16 < 100. 64 < 100. 256 >= 100.
    # So ceil(log4(100)) = 4.
    # p = 31 + 4 = 35. 35 > 63? No. 35 is valid.
    # Let's try k=50? No, k limit is 31 in prompt.
    # Let's try k=30, a=100.
    # p = 30 + 4 = 34.
    
    dut.valid_in.value = 1
    dut.k_in.value = 30
    dut.a_in.value = 100
    dut.type_index.value = 0
    await RisingEdge(dut.clk)
    
    dut.k_in.value = 0
    dut.a_in.value = 1
    dut.type_index.value = 1
    await RisingEdge(dut.clk)
    
    dut.k_in.value = 0
    dut.a_in.value = 1
    dut.type_index.value = 2
    await RisingEdge(dut.clk)
    
    dut.k_in.value = 0
    dut.a_in.value = 1
    dut.type_index.value = 3
    await RisingEdge(dut.clk)
    
    dut.valid_in.value = 0
    
    for _ in range(30):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
            
    if dut.done.value != 1:
        raise TestFailure("Module did not assert done signal")
        
    # Result should be 34
    if int(dut.result.value) != 34:
        raise TestFailure(f"Expected result 34, got {int(dut.result.value)}")
