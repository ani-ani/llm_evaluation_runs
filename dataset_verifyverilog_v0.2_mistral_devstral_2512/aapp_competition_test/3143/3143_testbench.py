import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import random

@cocotb.test()
async def test_attendance_solver(dut):
    """Test the attendance solver module"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.student_name_in.value = 0
    dut.required_name_in.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: N=1, M=1
    # List: [1], Queue: [1]
    # Expected: 1 inspection, position 1
    dut._log.info("Test Case 1: N=1, M=1")
    
    # Load queue
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Provide inputs sequentially
    # Queue: 1
    dut.student_name_in.value = 1
    await RisingEdge(dut.clk)
    
    # List: 1
    dut.required_name_in.value = 1
    await RisingEdge(dut.clk)
    
    # Wait for computation
    for _ in range(600):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    # Check results
    insp = int(dut.total_inspections.value)
    dut._log.info(f"Case 1: Total inspections = {insp}")
    assert insp == 1, f"Expected 1, got {insp}"
    
    # Test Case 2: N=4, M=5
    # List: [4,1,2,4,4], Queue: [4,3,2,1]
    # Expected: 7 inspections, positions as in example
    dut._log.info("Test Case 2: N=4, M=5")
    
    # Reset for next test
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Load queue: 4,3,2,1
    dut.student_name_in.value = 4
    await RisingEdge(dut.clk)
    dut.student_name_in.value = 3
    await RisingEdge(dut.clk)
    dut.student_name_in.value = 2
    await RisingEdge(dut.clk)
    dut.student_name_in.value = 1
    await RisingEdge(dut.clk)
    
    # Load list: 4,1,2,4,4
    dut.required_name_in.value = 4
    await RisingEdge(dut.clk)
    dut.required_name_in.value = 1
    await RisingEdge(dut.clk)
    dut.required_name_in.value = 2
    await RisingEdge(dut.clk)
    dut.required_name_in.value = 4
    await RisingEdge(dut.clk)
    dut.required_name_in.value = 4
    await RisingEdge(dut.clk)
    
    # Wait for computation
    for _ in range(600):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    insp = int(dut.total_inspections.value)
    dut._log.info(f"Case 2: Total inspections = {insp}")
    assert insp == 7, f"Expected 7, got {insp}"
    
    # Test Case 3: N=2, M=2
    # List: [1,2], Queue: [2,1]
    # Expected: 3 inspections
    dut._log.info("Test Case 3: N=2, M=2")
    
    # Reset
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Load queue: 2,1
    dut.student_name_in.value = 2
    await RisingEdge(dut.clk)
    dut.student_name_in.value = 1
    await RisingEdge(dut.clk)
    
    # Load list: 1,2
    dut.required_name_in.value = 1
    await RisingEdge(dut.clk)
    dut.required_name_in.value = 2
    await RisingEdge(dut.clk)
    
    # Wait for computation
    for _ in range(600):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    insp = int(dut.total_inspections.value)
    dut._log.info(f"Case 3: Total inspections = {insp}")
    assert insp == 3, f"Expected 3, got {insp}"
    
    dut._log.info("All tests completed successfully!")