import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits - 1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

# Constants
CLK_NS = 10
MAX_CYCLES = 1000
DATA_WIDTH = 8
ARRAY_SIZE = 8

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

def pack_data(sub_arrays):
    """Pack list of 8-bit values into 64-bit word"""
    result = 0
    for i, val in enumerate(sub_arrays):
        result |= (clamp_to_width(val, 8) << (i * 8))
    return result

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_list_counter(dut):
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational design
        await Timer(100, units='ns')
        return
    
    # Test cases
    # Format: (sub_arrays, expected_count, description)
    test_cases = [
        # Test 1: 2 sub-arrays
        ([1, 2, 3, 4, 5, 6, 7, 8], 2, "Two sub-arrays"),
        # Test 2: 3 sub-arrays
        ([1, 2, 3, 4, 5, 6, 0, 0], 3, "Three sub-arrays"),
        # Test 3: 1 sub-array
        ([9, 8, 7, 6, 5, 4, 3, 2], 1, "Single sub-array"),
        # Test 4: 0 sub-arrays
        ([0, 0, 0, 0, 0, 0, 0, 0], 0, "Empty collection"),
        # Test 5: Maximum sub-arrays (8)
        ([1, 2, 3, 4, 5, 6, 7, 8], 8, "Maximum sub-arrays")
    ]
    
    passed = 0
    failed = 0
    
    for i, (sub_arrays, expected_count, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i + 1}: {description}")
        try:
            # Pack the sub-arrays into 64-bit data
            packed_data = pack_data(sub_arrays)
            
            # Set inputs
            dut.data_in.value = packed_data
            dut.length.value = clamp_to_width(expected_count, 4)
            dut.start.value = 1
            
            # Wait for clock edge
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Check result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            
            if result != expected_count:
                raise TestFailure(f"Expected {expected_count}, got {result}")
            
            passed += 1
            cocotb.log.info(f"PASS: Got expected result {result}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    # Report summary
    cocotb.log.info(f"\nTest Summary: {passed} passed, {failed} failed")
    
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_reset_behavior(dut):
    """Test that reset properly clears all signals"""
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')
        return
    
    # Check reset state
    await Timer(10, units='ns')
    
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result undefined after reset")
    
    result_after_reset = int(dut.result.value)
    if result_after_reset != 0:
        raise TestFailure(f"Result should be 0 after reset, got {result_after_reset}")
    
    if not is_value_defined(dut.done.value):
        raise TestFailure("Done undefined after reset")
    
    done_after_reset = int(dut.done.value)
    if done_after_reset != 0:
        raise TestFailure(f"Done should be 0 after reset, got {done_after_reset}")
    
    cocotb.log.info("Reset behavior test passed")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_consecutive_operations(dut):
    """Test multiple consecutive operations without reset"""
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')
        return
    
    # First operation
    dut.data_in.value = pack_data([1, 2, 3, 4, 5, 6, 7, 8])
    dut.length.value = 2
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await wait_for_done(dut)
    
    result1 = int(dut.result.value)
    if result1 != 2:
        raise TestFailure(f"First operation: expected 2, got {result1}")
    
    # Second operation
    dut.data_in.value = pack_data([1, 2, 3, 4, 5, 6, 7, 8])
    dut.length.value = 4
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await wait_for_done(dut)
    
    result2 = int(dut.result.value)
    if result2 != 4:
        raise TestFailure(f"Second operation: expected 4, got {result2}")
    
    cocotb.log.info("Consecutive operations test passed")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_edge_cases(dut):
    """Test edge cases: zero, maximum length, etc."""
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')
        return
    
    # Edge case 1: Zero length
    dut.data_in.value = 0
    dut.length.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await wait_for_done(dut)
    
    result = int(dut.result.value)
    if result != 0:
        raise TestFailure(f"Zero length: expected 0, got {result}")
    
    # Edge case 2: Maximum length (8)
    dut.data_in.value = pack_data([1, 2, 3, 4, 5, 6, 7, 8])
    dut.length.value = 8
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await wait_for_done(dut)
    
    result = int(dut.result.value)
    if result != 8:
        raise TestFailure(f"Maximum length: expected 8, got {result}")
    
    # Edge case 3: Single element
    dut.data_in.value = pack_data([1, 0, 0, 0, 0, 0, 0, 0])
    dut.length.value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await wait_for_done(dut)
    
    result = int(dut.result.value)
    if result != 1:
        raise TestFailure(f"Single element: expected 1, got {result}")
    
    cocotb.log.info("Edge cases test passed")