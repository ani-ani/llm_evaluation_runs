import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
import random

@cocotb.test()
async def test_salary_damage_calculator(dut):
    """Test the simplified salary damage calculator"""
    
    # Create clock (10ns period)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.L0.value = 0
    dut.R0.value = 0
    dut.L1.value = 0
    dut.R1.value = 0
    dut.L2.value = 0
    dut.R2.value = 0
    dut.L3.value = 0
    dut.R3.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    print("
=== Test 1: Example from problem (scaled to 4 workers) ===")
    # Original example had 2 workers: [1.2, 10.2] and [2.2, 15.2]
    # Expected: E[diff] = (15.2+2.2)/2 - (10.2+1.2)/2 = 8.7 - 5.7 = 3.0
    # But original formula is more complex. Let's use a simple test case.
    # Worker 0: L=1.0, R=2.0 (E=1.5)
    # Worker 1: L=3.0, R=4.0 (E=3.5)
    # Worker 2: L=5.0, R=6.0 (E=5.5)
    # Worker 3: L=7.0, R=8.0 (E=7.5)
    # Pairwise diffs: (3.5-1.5) + (5.5-1.5) + (7.5-1.5) + (5.5-3.5) + (7.5-3.5) + (7.5-5.5)
    # = 2 + 4 + 6 + 2 + 4 + 2 = 20
    # Divided by 16 = 1.25
    
    # In Q16.16: 1.0 = 0x00010000, 2.0 = 0x00020000, etc.
    dut.L0.value = 0x00010000  # 1.0
    dut.R0.value = 0x00020000  # 2.0
    dut.L1.value = 0x00030000  # 3.0
    dut.R1.value = 0x00040000  # 4.0
    dut.L2.value = 0x00050000  # 5.0
    dut.R2.value = 0x00060000  # 6.0
    dut.L3.value = 0x00070000  # 7.0
    dut.R3.value = 0x00080000  # 8.0
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 0
    while not dut.done.value and timeout < 50:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert dut.done.value == 1, "Done signal should be high"
    
    # Expected result: 20/16 = 1.25 = 0x00014000 in Q16.16
    # 1.25 * 65536 = 81920 = 0x00014000
    expected = 81920
    actual = int(dut.result.value)
    print(f"Expected: {expected} (0x{expected:08X}), Got: {actual} (0x{actual:08X})")
    assert actual == expected, f"Expected {expected}, got {actual}"
    print("Test 1 passed!")
    
    print("
=== Test 2: All same values ===")
    # All workers have same range [1,2], E=1.5
    # All pairwise diffs = 0, result = 0
    dut.L0.value = 0x00010000
    dut.R0.value = 0x00020000
    dut.L1.value = 0x00010000
    dut.R1.value = 0x00020000
    dut.L2.value = 0x00010000
    dut.R2.value = 0x00020000
    dut.L3.value = 0x00010000
    dut.R3.value = 0x00020000
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 50:
        await RisingEdge(dut.clk)
        timeout += 1
    
    actual = int(dut.result.value)
    print(f"Result: {actual} (should be 0)")
    assert actual == 0, f"Expected 0, got {actual}"
    print("Test 2 passed!")
    
    print("
=== Test 3: Zero values ===")
    # Edge case: some ranges at 0
    # Note: L>=1 in problem, but testing edge of valid hardware range
    dut.L0.value = 0x00000000
    dut.R0.value = 0x00008000  # 0.5
    dut.L1.value = 0x00010000  # 1.0
    dut.R1.value = 0x00020000  # 2.0
    dut.L2.value = 0x00020000  # 2.0
    dut.R2.value = 0x00040000  # 4.0
    dut.L3.value = 0x00040000  # 4.0
    dut.R3.value = 0x00080000  # 8.0
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 50:
        await RisingEdge(dut.clk)
        timeout += 1
    
    actual = int(dut.result.value)
    print(f"Result: {actual} (0x{actual:08X})")
    # E[0] = 0.25, E[1] = 1.5, E[2] = 3.0, E[3] = 6.0
    # Pairwise: (1.5-0.25) + (3.0-0.25) + (6.0-0.25) + (3.0-1.5) + (6.0-1.5) + (6.0-3.0)
    # = 1.25 + 2.75 + 5.75 + 1.5 + 4.5 + 3.0 = 18.75
    # Result = 18.75/16 = 1.171875
    expected_val = int(1.171875 * 65536)
    print(f"Expected: {expected_val}")
    assert actual == expected_val, f"Expected {expected_val}, got {actual}"
    print("Test 3 passed!")
    
    print("
=== Test 4: Large values ===")
    # Test with values near max for Q16.16 format
    # Using 100.0 and 200.0
    dut.L0.value = 100 * 65536
    dut.R0.value = 150 * 65536
    dut.L1.value = 200 * 65536
    dut.R1.value = 250 * 65536
    dut.L2.value = 300 * 65536
    dut.R2.value = 350 * 65536
    dut.L3.value = 400 * 65536
    dut.R3.value = 450 * 65536
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 50:
        await RisingEdge(dut.clk)
        timeout += 1
    
    actual = int(dut.result.value)
    # E[0] = 125, E[1] = 225, E[2] = 325, E[3] = 425
    # Pairwise: (225-125) + (325-125) + (425-125) + (325-225) + (425-225) + (425-325)
    # = 100 + 200 + 300 + 100 + 200 + 100 = 1000
    # Result = 1000/16 = 62.5
    expected_val = int(62.5 * 65536)
    print(f"Result: {actual}, Expected: {expected_val}")
    assert actual == expected_val, f"Expected {expected_val}, got {actual}"
    print("Test 4 passed!")
    
    print("
=== All 4 tests passed! ===")
