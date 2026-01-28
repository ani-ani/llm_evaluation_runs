import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

@cocotb.test(timeout_time=5, timeout_unit='ms')
async def test_intersperse_basic(dut):
    """Test basic functionality with simple arrays."""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.delimiter.value = 0
    dut.length.value = 0
    for i in range(8):
        dut.arr[i].value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut._log.info("Test 1: Empty array")
    dut.delimiter.value = 7
    dut.length.value = 0
    for i in range(8):
        dut.arr[i].value = 0
    await RisingEdge(dut.clk)
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done (should be quick for empty)
    timeout_cycles = 20
    for cycle in range(timeout_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            break
    else:
        raise TestFailure("Test 1: Timeout waiting for done")
    
    dut._log.info("Test 1 passed [OK]")
    
    # Test 2: [1, 2, 3] with delimiter 4
    dut._log.info("Test 2: [1, 2, 3] with delimiter 4")
    dut.delimiter.value = 4
    dut.length.value = 3
    dut.arr[0].value = 1
    dut.arr[1].value = 2
    dut.arr[2].value = 3
    for i in range(3, 8):
        dut.arr[i].value = 0
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Expected output: 1, 4, 2, 4, 3
    expected = [1, 4, 2, 4, 3]
    
    for i, exp_val in enumerate(expected):
        # Wait for valid output
        cycle_count = 0
        while cycle_count < 20:
            await RisingEdge(dut.clk)
            cycle_count += 1
            if is_value_defined(dut.valid.value) and dut.valid.value == 1:
                if is_value_defined(dut.result.value):
                    actual = int(dut.result.value)
                    if actual != exp_val:
                        raise TestFailure(f"Test 2: At position {i}, expected {exp_val}, got {actual}")
                    dut._log.info(f"  Output {i}: {actual} [OK]")
                    break
        else:
            raise TestFailure(f"Test 2: Timeout waiting for valid output at position {i}")
    
    # Wait for done
    for cycle in range(10):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            dut._log.info("Test 2: Done signal received [OK]")
            break
    else:
        raise TestFailure("Test 2: Timeout waiting for done")
    
    # Test 3: [5, 6, 3, 2] with delimiter 8
    dut._log.info("Test 3: [5, 6, 3, 2] with delimiter 8")
    dut.delimiter.value = 8
    dut.length.value = 4
    dut.arr[0].value = 5
    dut.arr[1].value = 6
    dut.arr[2].value = 3
    dut.arr[3].value = 2
    for i in range(4, 8):
        dut.arr[i].value = 0
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Expected output: 5, 8, 6, 8, 3, 8, 2
    expected = [5, 8, 6, 8, 3, 8, 2]
    
    for i, exp_val in enumerate(expected):
        cycle_count = 0
        while cycle_count < 20:
            await RisingEdge(dut.clk)
            cycle_count += 1
            if is_value_defined(dut.valid.value) and dut.valid.value == 1:
                if is_value_defined(dut.result.value):
                    actual = int(dut.result.value)
                    if actual != exp_val:
                        raise TestFailure(f"Test 3: At position {i}, expected {exp_val}, got {actual}")
                    dut._log.info(f"  Output {i}: {actual} [OK]")
                    break
        else:
            raise TestFailure(f"Test 3: Timeout waiting for valid output at position {i}")
    
    # Wait for done
    for cycle in range(10):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            dut._log.info("Test 3: Done signal received [OK]")
            break
    else:
        raise TestFailure("Test 3: Timeout waiting for done")
    
    # Test 4: [2, 2, 2] with delimiter 2
    dut._log.info("Test 4: [2, 2, 2] with delimiter 2")
    dut.delimiter.value = 2
    dut.length.value = 3
    dut.arr[0].value = 2
    dut.arr[1].value = 2
    dut.arr[2].value = 2
    for i in range(3, 8):
        dut.arr[i].value = 0
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Expected output: 2, 2, 2, 2, 2
    expected = [2, 2, 2, 2, 2]
    
    for i, exp_val in enumerate(expected):
        cycle_count = 0
        while cycle_count < 20:
            await RisingEdge(dut.clk)
            cycle_count += 1
            if is_value_defined(dut.valid.value) and dut.valid.value == 1:
                if is_value_defined(dut.result.value):
                    actual = int(dut.result.value)
                    if actual != exp_val:
                        raise TestFailure(f"Test 4: At position {i}, expected {exp_val}, got {actual}")
                    dut._log.info(f"  Output {i}: {actual} [OK]")
                    break
        else:
            raise TestFailure(f"Test 4: Timeout waiting for valid output at position {i}")
    
    # Wait for done
    for cycle in range(10):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            dut._log.info("Test 4: Done signal received [OK]")
            break
    else:
        raise TestFailure("Test 4: Timeout waiting for done")
    
    # Test 5: Single element
    dut._log.info("Test 5: Single element [42]")
    dut.delimiter.value = 5
    dut.length.value = 1
    dut.arr[0].value = 42
    for i in range(1, 8):
        dut.arr[i].value = 0
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Expected output: 42 only
    expected = [42]
    
    for i, exp_val in enumerate(expected):
        cycle_count = 0
        while cycle_count < 20:
            await RisingEdge(dut.clk)
            cycle_count += 1
            if is_value_defined(dut.valid.value) and dut.valid.value == 1:
                if is_value_defined(dut.result.value):
                    actual = int(dut.result.value)
                    if actual != exp_val:
                        raise TestFailure(f"Test 5: At position {i}, expected {exp_val}, got {actual}")
                    dut._log.info(f"  Output {i}: {actual} [OK]")
                    break
        else:
            raise TestFailure(f"Test 5: Timeout waiting for valid output at position {i}")
    
    # Wait for done
    for cycle in range(10):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            dut._log.info("Test 5: Done signal received [OK]")
            break
    else:
        raise TestFailure("Test 5: Timeout waiting for done")
    
    dut._log.info("All 5 tests passed!")
