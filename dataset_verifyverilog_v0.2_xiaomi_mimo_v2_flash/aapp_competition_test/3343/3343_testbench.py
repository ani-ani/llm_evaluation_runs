import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_wire_bending_safe(dut):
    """Test case where wire does not touch itself"""
    # Clock setup
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.bend_valid.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Test case: L=8, bends at positions 3,2,1 all counter-clockwise
    # This simulates the sample input: 4 3; 3 C; 2 C; 1 C (scaled to L=8)
    # But we use 3,2,1 to test safe behavior
    # Expected: creates an "L" shape without self-intersection
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for state to become READ_BEND
    await Timer(200, units='ns')
    
    # Send bend 3 C (bend_point=3, dir=C=1)
    dut.bend_point.value = 3
    dut.bend_dir.value = 1
    dut.bend_valid.value = 1
    await RisingEdge(dut.clk)
    dut.bend_valid.value = 0
    
    # Wait for processing
    await Timer(500, units='ns')
    await RisingEdge(dut.clk)
    
    # Send bend 2 C (bend_point=2, dir=C=1)
    dut.bend_point.value = 2
    dut.bend_dir.value = 1
    dut.bend_valid.value = 1
    await RisingEdge(dut.clk)
    dut.bend_valid.value = 0
    
    await Timer(500, units='ns')
    await RisingEdge(dut.clk)
    
    # Send bend 1 C (bend_point=1, dir=C=1)
    dut.bend_point.value = 1
    dut.bend_dir.value = 1
    dut.bend_valid.value = 1
    await RisingEdge(dut.clk)
    dut.bend_valid.value = 0
    
    # Wait for completion
    await Timer(1000, units='ns')
    
    # Check results
    dut._log.info(f"Ghost signal: {dut.ghost.value}")
    dut._log.info(f"Done signal: {dut.done.value}")
    
    # Assert that wire is safe (no ghost)
    assert dut.ghost.value == 0, "Wire should be safe but ghost detected"
    assert dut.done.value == 1, "Should be done after all bends"
    print("Test 1 passed: Safe case works correctly")

@cocotb.test()
async def test_wire_bending_ghost(dut):
    """Test case where wire touches itself (crossing)"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.bend_valid.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Test case: bends that cause crossing
    # L=8, bend at 3 C, then 1 C (creates overlap)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await Timer(200, units='ns')
    
    # Bend 3 C
    dut.bend_point.value = 3
    dut.bend_dir.value = 1
    dut.bend_valid.value = 1
    await RisingEdge(dut.clk)
    dut.bend_valid.value = 0
    
    await Timer(500, units='ns')
    await RisingEdge(dut.clk)
    
    # Bend 1 C - this should cause crossing
    dut.bend_point.value = 1
    dut.bend_dir.value = 1
    dut.bend_valid.value = 1
    await RisingEdge(dut.clk)
    dut.bend_valid.value = 0
    
    await Timer(1000, units='ns')
    
    dut._log.info(f"Ghost signal: {dut.ghost.value}")
    
    # Assert that ghost is detected
    assert dut.ghost.value == 1, "Wire should have touched itself (ghost detected)"
    print("Test 2 passed: Ghost detection works correctly")

@cocotb.test()
async def test_wire_bending_empty(dut):
    """Test case with no bends - should be safe"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.bend_valid.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Start without any bends
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (should handle no bends gracefully)
    await Timer(200, units='ns')
    
    dut._log.info(f"Ghost signal: {dut.ghost.value}")
    
    # With no bends, wire is straight line, no ghost
    assert dut.ghost.value == 0, "Empty wire should be safe"
    print("Test 3 passed: Empty case works correctly")

@cocotb.test()
async def test_wire_bending_max_bends(dut):
    """Test with maximum bends"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.bend_valid.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await Timer(200, units='ns')
    
    # Send 8 alternating bends
    bends = [(7,0), (6,1), (5,0), (4,1), (3,0), (2,1), (1,0), (0,1)]
    
    for point, dir in bends:
        dut.bend_point.value = point
        dut.bend_dir.value = dir
        dut.bend_valid.value = 1
        await RisingEdge(dut.clk)
        dut.bend_valid.value = 0
        await Timer(500, units='ns')
        await RisingEdge(dut.clk)
    
    await Timer(1000, units='ns')
    
    dut._log.info(f"Ghost signal: {dut.ghost.value}")
    
    # Just verify it doesn't crash; result depends on geometry
    print(f"Test 4 passed: Max bends handled (result: {'GHOST' if dut.ghost.value else 'SAFE'})")

@cocotb.test()
async def test_wire_bending_clockwise(dut):
    """Test clockwise bends"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.bend_valid.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await Timer(200, units='ns')
    
    # Send 3 clockwise bends
    for point in [3, 2, 1]:
        dut.bend_point.value = point
        dut.bend_dir.value = 0  # clockwise
        dut.bend_valid.value = 1
        await RisingEdge(dut.clk)
        dut.bend_valid.value = 0
        await Timer(500, units='ns')
        await RisingEdge(dut.clk)
    
    await Timer(1000, units='ns')
    
    dut._log.info(f"Ghost signal: {dut.ghost.value}")
    dut._log.info(f"Done signal: {dut.done.value}")
    
    print(f"Test 5 passed: Clockwise bends handled")
    
print("
=== Summary ===")
print("Wire Bending Tests Completed")
print("Tests verify: Safe case, Ghost detection, Empty wire, Max bends, Clockwise")