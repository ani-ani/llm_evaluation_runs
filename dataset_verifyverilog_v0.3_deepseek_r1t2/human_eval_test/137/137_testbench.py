import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper function to check for X/Z values
def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def to_q88(value):
    """Convert decimal value to Q8.8 fixed-point representation."""
    # Multiply by 256 and round to nearest integer
    return int(value * 256)

def from_q88(value):
    """Convert Q8.8 fixed-point to decimal value."""
    # Handle signed 16-bit two's complement
    if value >= 32768:  # MSB is 1, negative number
        value = value - 65536
    integer_part = value // 256
    fractional_part = (value % 256) / 256.0
    return integer_part + fractional_part

@cocotb.test(timeout_time=2, timeout_unit="ms")
async def test_compare_one(dut):
    """Test the compare_one module with various Q8.8 values."""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.a.value = 0
    dut.b.value = 0
    dut.a_is_string.value = 0
    dut.b_is_string.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (a, b, a_is_string, b_is_string, expected_value, description)
    # Expected value: None (equal) -> 0x8000, otherwise Q8.8 of larger value
    test_cases = [
        # Simple integers
        (1, 2, 0, 0, 2, "compare(1, 2) -> 2"),
        (1, 2.5, 0, 0, 2.5, "compare(1, 2.5) -> 2.5"),
        (2, 3, 0, 0, 3, "compare(2, 3) -> 3"),
        (5, 6, 0, 0, 6, "compare(5, 6) -> 6"),
        
        # Mixed with strings
        (1, 2.3, 0, 1, 2.3, "compare(1, '2,3') -> '2,3'"),
        (5.1, 6, 1, 0, 6, "compare('5,1', '6') -> '6'"),
        (1, 2, 1, 1, 2, "compare('1', '2') -> '2'"),
        
        # Equal values (return None -> 0x8000)
        (1, 1, 0, 0, 0x8000, "compare(1, 1) -> None"),
        (2.5, 2.5, 0, 0, 0x8000, "compare(2.5, 2.5) -> None"),
        
        # Edge cases
        (-1, 0, 0, 0, 0, "compare(-1, 0) -> 0"),
        (0, -1, 0, 0, 0, "compare(0, -1) -> 0"),
        (127, -128, 0, 0, 127, "compare(127, -128) -> 127"),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (a_val, b_val, a_str, b_str, expected, description) in enumerate(test_cases):
        # Convert values to Q8.8 format
        a_q88 = to_q88(a_val)
        b_q88 = to_q88(b_val)
        
        # Ensure values fit in 16 bits (signed)
        a_q88 = a_q88 & 0xFFFF
        b_q88 = b_q88 & 0xFFFF
        
        # Set inputs
        dut.a.value = a_q88
        dut.b.value = b_q88
        dut.a_is_string.value = a_str
        dut.b_is_string.value = b_str
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal with timeout
        max_cycles = 10
        done_found = False
        for cycle in range(max_cycles):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and dut.done.value == 1:
                done_found = True
                break
        
        if not done_found:
            raise TestFailure(f"Test {i}: Done signal not asserted within {max_cycles} cycles")
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {i}: Result is undefined (X/Z)")
        
        result = int(dut.result.value)
        
        # Convert expected to Q8.8 or special value
        if expected == 0x8000:
            expected_q88 = 0x8000
        else:
            expected_q88 = to_q88(expected)
            expected_q88 = expected_q88 & 0xFFFF
        
        # Check result
        if result == expected_q88:
            dut._log.info(f"[OK] Test {i}: {description} - Result: 0x{result:04X}")
            passed += 1
        else:
            result_dec = from_q88(result)
            expected_dec = from_q88(expected_q88) if expected_q88 != 0x8000 else "None"
            raise TestFailure(
                f"Test {i}: {description}\n"
                f"  Expected: 0x{expected_q88:04X} ({expected_dec})\n"
                f"  Got:      0x{result:04X} ({result_dec})"
            )
        
        # Wait a cycle before next test
        await RisingEdge(dut.clk)
    
    dut._log.info(f"\n=== Summary: {passed}/{total} tests passed ===")
    if passed != total:
        raise TestFailure(f"Only {passed} out of {total} tests passed")

@cocotb.test(timeout_time=1, timeout_unit="ms")
async def test_reset_behavior(dut):
    """Verify that reset properly initializes the module."""
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Apply reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    # Check outputs are zero after reset
    if is_value_defined(dut.done.value) and dut.done.value != 0:
        raise TestFailure("Done signal not low after reset")
    
    if is_value_defined(dut.result.value) and dut.result.value != 0:
        raise TestFailure(f"Result not zero after reset: {dut.result.value}")
    
    # Deassert reset and verify module can start
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Simple test
    dut.a.value = to_q88(5)
    dut.b.value = to_q88(3)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    for _ in range(5):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            if int(dut.result.value) == to_q88(5):
                dut._log.info("[OK] Reset test passed")
                return
    
    raise TestFailure("Module did not function correctly after reset")
