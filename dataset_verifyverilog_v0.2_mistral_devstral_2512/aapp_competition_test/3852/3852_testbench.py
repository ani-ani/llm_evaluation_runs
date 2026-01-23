import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from cocotb.result import TestFailure, TestSuccess
import random

@cocotb.test()
async def test_basic_non_decreasing(dut):
    """Test basic non-decreasing sequence generation"""
    
    # Create clock (10ns period = 100MHz)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Initialize
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.a_in.value = 0
    dut.idx.value = 0
    dut.valid_in.value = 0
    
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: [-2, 5, -1] (from problem)
    dut._log.info("Test Case 1: [-2, 5, -1]")
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Load array elements (N=3)
    test_array = [-2, 5, -1]
    for i, val in enumerate(test_array):
        dut.a_in.value = val
        dut.idx.value = i
        dut.valid_in.value = 1
        await RisingEdge(dut.clk)
    
    dut.valid_in.value = 0
    
    # Wait for analysis and operation generation
    ops = []
    op_count = 0
    timeout = 100
    
    while timeout > 0:
        await RisingEdge(dut.clk)
        timeout -= 1
        
        if dut.op_valid.value:
            x = int(dut.op_x.value)
            y = int(dut.op_y.value)
            ops.append((x, y))
            op_count += 1
            dut._log.info(f"Operation {op_count}: add a[{x}] to a[{y}]")
        
        if dut.done.value:
            dut._log.info(f"Done signal received. Total ops: {op_count}")
            break
    
    # Verify operations were generated
    assert op_count > 0, "Expected at least 1 operation"
    assert op_count <= 32, f"Too many operations: {op_count}"
    
    # Verify operations don't exceed 2N limit
    if op_count > 6:
        raise TestFailure(f"Operations {op_count} exceed 2N=6 for N=3")
    
    dut._log.info(f"Test Case 1 passed with {op_count} operations")

@cocotb.test()
async def test_all_positive(dut):
    """Test case with all positive numbers (should need no operations or simple prefix)"""
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_in.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test: [1, 3, 2, 4]
    dut._log.info("Test Case 2: All positive [1, 3, 2, 4]")
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    test_array = [1, 3, 2, 4]
    for i, val in enumerate(test_array):
        dut.a_in.value = val
        dut.idx.value = i
        dut.valid_in.value = 1
        await RisingEdge(dut.clk)
    
    dut.valid_in.value = 0
    
    # Wait for completion
    ops = []
    timeout = 80
    while timeout > 0:
        await RisingEdge(dut.clk)
        timeout -= 1
        
        if dut.op_valid.value:
            ops.append((int(dut.op_x.value), int(dut.op_y.value)))
        
        if dut.done.value:
            break
    
    # Should have at most N-1 operations
    assert len(ops) <= 3, f"Too many operations for sorted input: {len(ops)}"
    dut._log.info(f"Test Case 2 passed with {len(ops)} operations")

@cocotb.test()
async def test_all_negative(dut):
    """Test case with all negative numbers"""
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_in.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test: [-5, -1, -3]
    dut._log.info("Test Case 3: All negative [-5, -1, -3]")
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    test_array = [-5, -1, -3]
    for i, val in enumerate(test_array):
        dut.a_in.value = val
        dut.idx.value = i
        dut.valid_in.value = 1
        await RisingEdge(dut.clk)
    
    dut.valid_in.value = 0
    
    ops = []
    timeout = 60
    while timeout > 0:
        await RisingEdge(dut.clk)
        timeout -= 1
        
        if dut.op_valid.value:
            ops.append((int(dut.op_x.value), int(dut.op_y.value)))
        
        if dut.done.value:
            break
    
    assert len(ops) > 0, "Expected operations for negative sequence"
    dut._log.info(f"Test Case 3 passed with {len(ops)} operations")

@cocotb.test()
async def test_boundary_max_ops(dut):
    """Test that module respects 2N operation limit"""
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_in.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Create worst-case scenario for N=16
    dut._log.info("Test Case 4: Maximum N test with alternating signs")
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Generate 16 elements with large alternating values
    test_array = []
    for i in range(16):
        if i % 2 == 0:
            test_array.append(-(1000 + i*100))  # Large negative
        else:
            test_array.append(1000 + i*100)     # Large positive
    
    for i, val in enumerate(test_array):
        dut.a_in.value = val
        dut.idx.value = i
        dut.valid_in.value = 1
        await RisingEdge(dut.clk)
    
    dut.valid_in.value = 0
    
    # Count all operations until done
    op_count = 0
    timeout = 200
    max_ops = 32  # 2*N limit
    
    while timeout > 0:
        await RisingEdge(dut.clk)
        timeout -= 1
        
        if dut.op_valid.value:
            op_count += 1
            if op_count > max_ops:
                raise TestFailure(f"Exceeded 2N limit: {op_count} ops")
        
        if dut.done.value:
            break
    
    assert op_count <= max_ops, f"Ops ({op_count}) exceeded 2N={max_ops}"
    dut._log.info(f"Test Case 4 passed: {op_count} ops within limit")

@cocotb.test()
async def test_single_element(dut):
    """Test with N=1 (edge case)"""
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_in.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut._log.info("Test Case 5: Single element [42]")
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    dut.a_in.value = 42
    dut.idx.value = 0
    dut.valid_in.value = 1
    await RisingEdge(dut.clk)
    dut.valid_in.value = 0
    
    # Should complete quickly with no operations
    timeout = 20
    ops = 0
    while timeout > 0:
        await RisingEdge(dut.clk)
        timeout -= 1
        if dut.op_valid.value:
            ops += 1
        if dut.done.value:
            break
    
    assert ops == 0, f"Single element should need 0 ops, got {ops}"
    dut._log.info("Test Case 5 passed")

@cocotb.test()
async def test_reset_during_ops(dut):
    """Test that reset works mid-computation"""
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_in.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut._log.info("Test Case 6: Reset during operation")
    
    # Start a sequence
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    test_array = [-100, 200, -50]
    for i, val in enumerate(test_array):
        dut.a_in.value = val
        dut.idx.value = i
        dut.valid_in.value = 1
        await RisingEdge(dut.clk)
    dut.valid_in.value = 0
    
    # Wait a bit, then reset
    await Timer(200, units='ns')
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    
    # Verify we're back in IDLE
    await RisingEdge(dut.clk)
    # Check state is reset (internal state reset)
    # Start again
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Re-load
    for i, val in enumerate(test_array):
        dut.a_in.value = val
        dut.idx.value = i
        dut.valid_in.value = 1
        await RisingEdge(dut.clk)
    dut.valid_in.value = 0
    
    # Should work again
    timeout = 60
    ops = 0
    while timeout > 0:
        await RisingEdge(dut.clk)
        timeout -= 1
        if dut.op_valid.value:
            ops += 1
        if dut.done.value:
            break
    
    assert ops > 0, "Reset test failed to generate operations"
    dut._log.info(f"Test Case 6 passed with {ops} ops after reset")

print("Testbench complete - all tests defined")
