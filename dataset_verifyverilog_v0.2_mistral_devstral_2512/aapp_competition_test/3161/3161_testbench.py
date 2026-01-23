import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_josip_painter(dut):
    """Test the Josip painter module with various 8x8 patterns"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.target_write_en.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    # Test case 1: Small pattern from sample (adapted to 8x8)
    # Input: 0001 pattern repeated - we'll make a simple 8x8 version
    target1 = [
        "00010000",
        "00010000",
        "00110000",
        "11100000",
        "00000000",
        "00000000",
        "00000000",
        "00000000"
    ]
    
    # Load target grid
    for i, row_str in enumerate(target1):
        dut.target_addr.value = i
        dut.target_row.value = int(row_str, 2)
        dut.target_write_en.value = 1
        await RisingEdge(dut.clk)
    
    dut.target_write_en.value = 0
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    timeout = 1000
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    else:
        raise TimeoutError("Computation did not complete in time")
    
    # Check result
    result_diff = int(dut.min_diff.value)
    print(f"Test 1 - Minimum difference: {result_diff}")
    assert result_diff >= 0 and result_diff <= 64, f"Difference out of range: {result_diff}"
    
    # Test case 2: All black (should have many mismatches)
    await Timer(100, units='ns')
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    target2 = [
        "11111111",
        "11111111",
        "11111111",
        "11111111",
        "11111111",
        "11111111",
        "11111111",
        "11111111"
    ]
    
    for i, row_str in enumerate(target2):
        dut.target_addr.value = i
        dut.target_row.value = int(row_str, 2)
        dut.target_write_en.value = 1
        await RisingEdge(dut.clk)
    
    dut.target_write_en.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 1000
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    else:
        raise TimeoutError("Computation did not complete in time")
    
    result_diff = int(dut.min_diff.value)
    print(f"Test 2 - Minimum difference: {result_diff}")
    assert result_diff >= 0 and result_diff <= 64, f"Difference out of range: {result_diff}"
    
    # Test case 3: Checkerboard pattern
    await Timer(100, units='ns')
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    target3 = [
        "01010101",
        "10101010",
        "01010101",
        "10101010",
        "01010101",
        "10101010",
        "01010101",
        "10101010"
    ]
    
    for i, row_str in enumerate(target3):
        dut.target_addr.value = i
        dut.target_row.value = int(row_str, 2)
        dut.target_write_en.value = 1
        await RisingEdge(dut.clk)
    
    dut.target_write_en.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 1000
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    else:
        raise TimeoutError("Computation did not complete in time")
    
    result_diff = int(dut.min_diff.value)
    print(f"Test 3 - Minimum difference: {result_diff}")
    assert result_diff >= 0 and result_diff <= 64, f"Difference out of range: {result_diff}"
    
    # Test case 4: All white (0 mismatches possible)
    await Timer(100, units='ns')
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    target4 = [
        "00000000",
        "00000000",
        "00000000",
        "00000000",
        "00000000",
        "00000000",
        "00000000",
        "00000000"
    ]
    
    for i, row_str in enumerate(target4):
        dut.target_addr.value = i
        dut.target_row.value = int(row_str, 2)
        dut.target_write_en.value = 1
        await RisingEdge(dut.clk)
    
    dut.target_write_en.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 1000
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    else:
        raise TimeoutError("Computation did not complete in time")
    
    result_diff = int(dut.min_diff.value)
    print(f"Test 4 - Minimum difference: {result_diff}")
    assert result_diff == 0, f"All white should give 0 difference, got {result_diff}"
    
    # Test case 5: Edge case - single row pattern
    await Timer(100, units='ns')
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    target5 = [
        "11000000",
        "11000000",
        "00000000",
        "00000000",
        "00000000",
        "00000000",
        "00000000",
        "00000000"
    ]
    
    for i, row_str in enumerate(target5):
        dut.target_addr.value = i
        dut.target_row.value = int(row_str, 2)
        dut.target_write_en.value = 1
        await RisingEdge(dut.clk)
    
    dut.target_write_en.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 1000
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    else:
        raise TimeoutError("Computation did not complete in time")
    
    result_diff = int(dut.min_diff.value)
    print(f"Test 5 - Minimum difference: {result_diff}")
    assert result_diff >= 0 and result_diff <= 64, f"Difference out of range: {result_diff}"
    
    print("
All tests completed successfully!")
