import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

@cocotb.test()
async def test_horse_chase(dut):
    """Test the horse chase module with sample inputs."""
    
    # Create a clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.L.value = 0
    dut.A.value = 0
    dut.B.value = 0
    dut.P.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: L=5, A=4, B=3, P=2 -> Expected Output: 3
    dut.L.value = 5
    dut.A.value = 4
    dut.B.value = 3
    dut.P.value = 2
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done signal (max 200 cycles to prevent infinite hang in sim)
    cycles = 0
    while dut.done.value == 0 and cycles < 200:
        await RisingEdge(dut.clk)
        cycles += 1
        
    if dut.done.value == 0:
        raise TestFailure(f"Test 1: Did not finish within 200 cycles")
        
    if dut.result.value != 3:
        raise TestFailure(f"Test 1: Expected 3, got {int(dut.result.value)}")
    print("Test 1 passed!")
    
    # Reset for next test
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 2: L=5, A=4, B=2, P=3 -> Expected Output: 3
    dut.L.value = 5
    dut.A.value = 4
    dut.B.value = 2
    dut.P.value = 3
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while dut.done.value == 0 and cycles < 200:
        await RisingEdge(dut.clk)
        cycles += 1
        
    if dut.done.value == 0:
        raise TestFailure(f"Test 2: Did not finish within 200 cycles")
        
    if dut.result.value != 3:
        raise TestFailure(f"Test 2: Expected 3, got {int(dut.result.value)}")
    print("Test 2 passed!")
