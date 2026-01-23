import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def to_signed(val, bits):
    """Convert unsigned to signed representation."""
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    """Convert signed to unsigned for assignment."""
    if val < 0:
        return val + (1 << bits)
    return val

@cocotb.test(timeout_time=500, timeout_unit="ms")
async def test_sort_even_basic(dut):
    """Test basic functionality with small arrays."""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    for i in range(16):
        getattr(dut, f'arr_{i}').value = 0
    dut.len.value = 0
    await Timer(50, units="ns")
    dut.rst_n.value = 1
    await Timer(20, units="ns")
    
    # Test case 1: [1, 2, 3] -> [1, 2, 3]
    dut._log.info("Test 1: len=3, [1, 2, 3]")
    test_len = 3
    test_arr = [1, 2, 3]
    for i in range(16):
        if i < test_len:
            getattr(dut, f'arr_{i}').value = from_signed(test_arr[i], 8)
        else:
            getattr(dut, f'arr_{i}').value = 0
    dut.len.value = test_len
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    max_cycles = 300
    done_found = False
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            done_found = True
            break
    
    if not done_found:
        raise TestFailure(f"Test 1: done signal not asserted after {max_cycles} cycles")
    
    # Check results
    expected = [1, 2, 3]
    for i in range(test_len):
        result_sig = getattr(dut, f'result_{i}')
        if not is_value_defined(result_sig.value):
            raise TestFailure(f"Test 1: result_{i} is undefined")
        result_val = to_signed(int(result_sig.value), 8)
        if result_val != expected[i]:
            raise TestFailure(f"Test 1 index {i}: expected {expected[i]}, got {result_val}")
    
    dut._log.info("Test 1 passed")
    await Timer(50, units="ns")

@cocotb.test(timeout_time=500, timeout_unit="ms")
async def test_sort_even_medium(dut):
    """Test with 4 elements."""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    for i in range(16):
        getattr(dut, f'arr_{i}').value = 0
    dut.len.value = 0
    await Timer(50, units="ns")
    dut.rst_n.value = 1
    await Timer(20, units="ns")
    
    # Test case 2: [5, 6, 3, 4] -> [3, 6, 5, 4]
    dut._log.info("Test 2: len=4, [5, 6, 3, 4]")
    test_len = 4
    test_arr = [5, 6, 3, 4]
    for i in range(16):
        if i < test_len:
            getattr(dut, f'arr_{i}').value = from_signed(test_arr[i], 8)
        else:
            getattr(dut, f'arr_{i}').value = 0
    dut.len.value = test_len
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    max_cycles = 300
    done_found = False
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            done_found = True
            break
    
    if not done_found:
        raise TestFailure(f"Test 2: done signal not asserted after {max_cycles} cycles")
    
    # Check results
    expected = [3, 6, 5, 4]
    for i in range(test_len):
        result_sig = getattr(dut, f'result_{i}')
        if not is_value_defined(result_sig.value):
            raise TestFailure(f"Test 2: result_{i} is undefined")
        result_val = to_signed(int(result_sig.value), 8)
        if result_val != expected[i]:
            raise TestFailure(f"Test 2 index {i}: expected {expected[i]}, got {result_val}")
    
    dut._log.info("Test 2 passed")
    await Timer(50, units="ns")

@cocotb.test(timeout_time=500, timeout_unit="ms")
async def test_sort_even_long(dut):
    """Test with 11 elements."""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    for i in range(16):
        getattr(dut, f'arr_{i}').value = 0
    dut.len.value = 0
    await Timer(50, units="ns")
    dut.rst_n.value = 1
    await Timer(20, units="ns")
    
    # Test case 3: [5, 3, -5, 2, -3, 3, 9, 0, 123, 1, -10] -> [-10, 3, -5, 2, -3, 3, 5, 0, 9, 1, 123]
    dut._log.info("Test 3: len=11, [5, 3, -5, 2, -3, 3, 9, 0, 123, 1, -10]")
    test_len = 11
    test_arr = [5, 3, -5, 2, -3, 3, 9, 0, 123, 1, -10]
    for i in range(16):
        if i < test_len:
            getattr(dut, f'arr_{i}').value = from_signed(test_arr[i], 8)
        else:
            getattr(dut, f'arr_{i}').value = 0
    dut.len.value = test_len
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    max_cycles = 300
    done_found = False
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            done_found = True
            break
    
    if not done_found:
        raise TestFailure(f"Test 3: done signal not asserted after {max_cycles} cycles")
    
    # Check results
    expected = [-10, 3, -5, 2, -3, 3, 5, 0, 9, 1, 123]
    for i in range(test_len):
        result_sig = getattr(dut, f'result_{i}')
        if not is_value_defined(result_sig.value):
            raise TestFailure(f"Test 3: result_{i} is undefined")
        result_val = to_signed(int(result_sig.value), 8)
        if result_val != expected[i]:
            raise TestFailure(f"Test 3 index {i}: expected {expected[i]}, got {result_val}")
    
    dut._log.info("Test 3 passed")
    await Timer(50, units="ns")

@cocotb.test(timeout_time=500, timeout_unit="ms")
async def test_sort_even_another(dut):
    """Test with 10 elements."""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    for i in range(16):
        getattr(dut, f'arr_{i}').value = 0
    dut.len.value = 0
    await Timer(50, units="ns")
    dut.rst_n.value = 1
    await Timer(20, units="ns")
    
    # Test case 4: [5, 8, -12, 4, 23, 2, 3, 11, 12, -10] -> [-12, 8, 3, 4, 5, 2, 12, 11, 23, -10]
    dut._log.info("Test 4: len=10, [5, 8, -12, 4, 23, 2, 3, 11, 12, -10]")
    test_len = 10
    test_arr = [5, 8, -12, 4, 23, 2, 3, 11, 12, -10]
    for i in range(16):
        if i < test_len:
            getattr(dut, f'arr_{i}').value = from_signed(test_arr[i], 8)
        else:
            getattr(dut, f'arr_{i}').value = 0
    dut.len.value = test_len
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    max_cycles = 300
    done_found = False
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            done_found = True
            break
    
    if not done_found:
        raise TestFailure(f"Test 4: done signal not asserted after {max_cycles} cycles")
    
    # Check results
    expected = [-12, 8, 3, 4, 5, 2, 12, 11, 23, -10]
    for i in range(test_len):
        result_sig = getattr(dut, f'result_{i}')
        if not is_value_defined(result_sig.value):
            raise TestFailure(f"Test 4: result_{i} is undefined")
        result_val = to_signed(int(result_sig.value), 8)
        if result_val != expected[i]:
            raise TestFailure(f"Test 4 index {i}: expected {expected[i]}, got {result_val}")
    
    dut._log.info("Test 4 passed")
    await Timer(50, units="ns")

@cocotb.test(timeout_time=500, timeout_unit="ms")
async def test_sort_even_edge_case(dut):
    """Test with 2 elements (minimum non-trivial case)."""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    for i in range(16):
        getattr(dut, f'arr_{i}').value = 0
    dut.len.value = 0
    await Timer(50, units="ns")
    dut.rst_n.value = 1
    await Timer(20, units="ns")
    
    # Test case: [10, 5] -> [5, 10] (only index 0 is even, becomes 5)
    dut._log.info("Test 5: len=2, [10, 5]")
    test_len = 2
    test_arr = [10, 5]
    for i in range(16):
        if i < test_len:
            getattr(dut, f'arr_{i}').value = from_signed(test_arr[i], 8)
        else:
            getattr(dut, f'arr_{i}').value = 0
    dut.len.value = test_len
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    max_cycles = 300
    done_found = False
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            done_found = True
            break
    
    if not done_found:
        raise TestFailure(f"Test 5: done signal not asserted after {max_cycles} cycles")
    
    # Check results
    expected = [5, 10]
    for i in range(test_len):
        result_sig = getattr(dut, f'result_{i}')
        if not is_value_defined(result_sig.value):
            raise TestFailure(f"Test 5: result_{i} is undefined")
        result_val = to_signed(int(result_sig.value), 8)
        if result_val != expected[i]:
            raise TestFailure(f"Test 5 index {i}: expected {expected[i]}, got {result_val}")
    
    dut._log.info("Test 5 passed")
    await Timer(50, units="ns")
    
    dut._log.info("All 5 tests passed [OK]")
