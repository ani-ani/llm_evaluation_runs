import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import struct

@cocotb.test()
async def test_max_aggregate(dut):
    """Test max_aggregate module with multiple test cases"""
    
    # Helper function to convert string to 64-bit encoding
    def str_to_bits(s):
        result = 0
        padded = s.ljust(8, ' ')[:8]
        for i, c in enumerate(padded):
            result |= ord(c) << (i * 8)
        return result
    
    # Setup clock and reset
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_in.value = 0
    dut.num_entries.value = 0
    await Timer(50, units='ns')
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 1: Original test case
    dut._log.info("Test 1: Multiple entries with duplicates")
    test_data = [
        ('Juan Whelan', 90),
        ('Sabah Colley', 88),
        ('Peter Nichols', 7),
        ('Juan Whelan', 122),
        ('Sabah Colley', 84)
    ]
    
    dut.num_entries.value = len(test_data)
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for name, marks in test_data:
        dut.valid_in.value = 1
        dut.name_in.value = str_to_bits(name)
        dut.marks_in.value = marks & 0xFF
        await RisingEdge(dut.clk)
    
    dut.valid_in.value = 0
    
    # Wait for completion
    timeout = 50
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    else:
        raise TestFailure("Test 1: Timeout waiting for done")
    
    expected_name = str_to_bits('Juan Whelan')
    expected_total = 212 & 0x3FF  # 10-bit signed
    
    if dut.result_name.value != expected_name:
        raise TestFailure(f"Test 1: Wrong name. Expected {expected_name:#x}, got {dut.result_name.value:#x}")
    if dut.result_total.value != expected_total:
        raise TestFailure(f"Test 1: Wrong total. Expected {expected_total}, got {dut.result_total.value}")
    
    dut._log.info(f"Test 1 passed: {dut.result_name.value}, {dut.result_total.value}")
    
    # Reset for next test
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 2
    dut._log.info("Test 2: Smaller values")
    test_data = [
        ('Juan Whelan', 50),
        ('Sabah Colley', 48),
        ('Peter Nichols', 37),
        ('Juan Whelan', 22),
        ('Sabah Colley', 14)
    ]
    
    dut.num_entries.value = len(test_data)
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for name, marks in test_data:
        dut.valid_in.value = 1
        dut.name_in.value = str_to_bits(name)
        dut.marks_in.value = marks & 0xFF
        await RisingEdge(dut.clk)
    
    dut.valid_in.value = 0
    
    timeout = 50
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    else:
        raise TestFailure("Test 2: Timeout waiting for done")
    
    expected_name = str_to_bits('Juan Whelan')
    expected_total = 72 & 0x3FF
    
    if dut.result_name.value != expected_name:
        raise TestFailure(f"Test 2: Wrong name. Expected {expected_name:#x}, got {dut.result_name.value:#x}")
    if dut.result_total.value != expected_total:
        raise TestFailure(f"Test 2: Wrong total. Expected {expected_total}, got {dut.result_total.value}")
    
    dut._log.info(f"Test 2 passed: {dut.result_name.value}, {dut.result_total.value}")
    
    # Reset for next test
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 3
    dut._log.info("Test 3: Different winner")
    test_data = [
        ('Juan Whelan', 10),
        ('Sabah Colley', 20),
        ('Peter Nichols', 30),
        ('Juan Whelan', 40),
        ('Sabah Colley', 50)
    ]
    
    dut.num_entries.value = len(test_data)
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for name, marks in test_data:
        dut.valid_in.value = 1
        dut.name_in.value = str_to_bits(name)
        dut.marks_in.value = marks & 0xFF
        await RisingEdge(dut.clk)
    
    dut.valid_in.value = 0
    
    timeout = 50
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    else:
        raise TestFailure("Test 3: Timeout waiting for done")
    
    expected_name = str_to_bits('Sabah Colley')
    expected_total = 70 & 0x3FF
    
    if dut.result_name.value != expected_name:
        raise TestFailure(f"Test 3: Wrong name. Expected {expected_name:#x}, got {dut.result_name.value:#x}")
    if dut.result_total.value != expected_total:
        raise TestFailure(f"Test 3: Wrong total. Expected {expected_total}, got {dut.result_total.value}")
    
    dut._log.info(f"Test 3 passed: {dut.result_name.value}, {dut.result_total.value}")
    
    # Reset for next test
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 4: Single entry
    dut._log.info("Test 4: Single entry")
    dut.num_entries.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    dut.valid_in.value = 1
    dut.name_in.value = str_to_bits('Alice')
    dut.marks_in.value = 100 & 0xFF
    await RisingEdge(dut.clk)
    dut.valid_in.value = 0
    
    timeout = 50
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    else:
        raise TestFailure("Test 4: Timeout waiting for done")
    
    expected_name = str_to_bits('Alice')
    expected_total = 100 & 0x3FF
    
    if dut.result_name.value != expected_name:
        raise TestFailure(f"Test 4: Wrong name. Expected {expected_name:#x}, got {dut.result_name.value:#x}")
    if dut.result_total.value != expected_total:
        raise TestFailure(f"Test 4: Wrong total. Expected {expected_total}, got {dut.result_total.value}")
    
    dut._log.info(f"Test 4 passed: {dut.result_name.value}, {dut.result_total.value}")
    
    # Reset for error test
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 5: Zero entries (error case)
    dut._log.info("Test 5: Zero entries (error)")
    dut.num_entries.value = 0
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 20
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    else:
        raise TestFailure("Test 5: Timeout waiting for done")
    
    if dut.error.value != 1:
        raise TestFailure(f"Test 5: Error flag should be high for zero entries")
    
    dut._log.info("Test 5 passed: error flag correctly set")
    
    # Summary
    dut._log.info("
=== All 5 tests passed ===")