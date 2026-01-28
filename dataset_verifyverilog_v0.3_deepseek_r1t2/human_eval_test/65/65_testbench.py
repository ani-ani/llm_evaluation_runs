import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure
import random

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

async def wait_for_valid_output(dut, timeout_ns=1000):
    """Poll for valid output in combinational logic."""
    elapsed = 0
    while elapsed < timeout_ns:
        await Timer(10, units='ns')
        elapsed += 10
        if is_value_defined(dut.result.value):
            return int(dut.result.value)
    raise TestFailure(f"Timeout: output not valid after {timeout_ns}ns")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_circular_shift(dut):
    """Test the circular shift module."""
    
    # Define helper function for rotation logic (Python reference)
    def rotate_right(val, shift, bits=32):
        shift = shift % bits
        if shift == 0:
            return val
        return ((val >> shift) | (val << (bits - shift))) & ((1 << bits) - 1)

    # Test cases adapted from Python problem
    # In binary, '12' is 0b1100. Circular shift right by 1 -> 0b0110 (6) -> wait, problem was decimal digits.
    # We are doing binary bits. Let's stick to the binary interpretation for hardware.
    
    test_cases = [
        # (input, shift, description)
        (0x12345678, 4, "Standard rotate"),
        (0x00000001, 1, "Shift 1, bit rolls"),
        (0x80000000, 1, "MSB to LSB"),
        (0xFFFFFFFF, 5, "All ones"),
        (0x0, 10, "Zero input"),
        (0x1, 0, "Zero shift"),
        (0x1, 32, "Shift 32 (equiv 0)"),
        (0xAAAA5555, 16, "Large shift"),
        (0x12345678, 1, "Shift 1"),
        (0x12345678, 31, "Shift 31"),
    ]

    passed = 0
    total = len(test_cases)

    for i, (val, shft, desc) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}/{total}: {desc} (val=0x{val:08X}, shift={shft})")
        
        # Set inputs
        dut.x.value = val
        dut.shift.value = shft
        
        # Wait for combinational propagation
        result = await wait_for_valid_output(dut, 1000)
        
        # Calculate expected
        expected = rotate_right(val, shft)
        
        # Verify
        if result != expected:
            raise TestFailure(f"Test {i+1} ({desc}) failed: expected 0x{expected:08X}, got 0x{result:08X}")
        
        passed += 1

    dut._log.info(f"Summary: {passed}/{total} tests passed")