import cocotb
from cocotb.triggers import Timer, RisingEdge
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

def to_ascii(digit):
    """Convert digit 0-9 to ASCII."""
    return 0x30 + digit

def count_odd_digits(digits):
    """Count odd digits in a string."""
    return sum(1 for d in digits if int(d) % 2 == 1)

def generate_expected_output(count):
    """Generate expected 16-byte output."""
    # Format: "X odd elements  " (16 chars)
    result = [0] * 16
    if count > 9:
        count = 9  # Clamp for single digit
    result[0] = to_ascii(count)
    # " odd elements  "
    fixed_str = " odd elements  "
    for i, char in enumerate(fixed_str):
        result[i + 1] = ord(char)
    return result

def pack_string(s, width=8):
    """Pad string to width and return as list of ASCII codes."""
    padded = s.ljust(width, ' ')
    return [ord(c) for c in padded]

@cocotb.test(timeout_time=2, timeout_unit="ms")
async def test_odd_count(dut):
    """Test the odd_count module with various inputs."""
    
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    for i in range(8):
        setattr(dut, f'char_{i}').value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (input_string, description)
    test_cases = [
        ("1234567", "Test 1: 4 odd digits"),
        ("3", "Test 2: 1 odd digit"),
        ("11111111", "Test 3: 8 odd digits"),
        ("271", "Test 4: 2 odd digits"),
        ("22222222", "Test 5: 0 odd digits"),
    ]
    
    for i, (input_str, description) in enumerate(test_cases):
        dut._log.info(f"\nRunning {description}")
        
        # Pack input string
        input_chars = pack_string(input_str, 8)
        
        # Apply inputs
        for j in range(8):
            setattr(dut, f'char_{j}').value = input_chars[j]
        
        # Wait for inputs to settle
        await Timer(20, units="ns")
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done with timeout
        max_cycles = 30
        done_seen = False
        for cycle in range(max_cycles):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value):
                if dut.done.value == 1:
                    done_seen = True
                    break
        
        if not done_seen:
            raise TestFailure(f"Test {i}: done signal not asserted within {max_cycles} cycles")
        
        # Verify output is defined
        output_bytes = []
        for j in range(16):
            signal = getattr(dut, f'out_{j}')
            if not is_value_defined(signal.value):
                raise TestFailure(f"Test {i}: out_{j} is undefined (X/Z)")
            output_bytes.append(int(signal.value))
        
        # Get expected result
        count = count_odd_digits(input_str)
        expected = generate_expected_output(count)
        
        # Compare
        if output_bytes != expected:
            dut._log.info(f"Input: '{input_str}', Count: {count}")
            dut._log.info(f"Expected: {[hex(b) for b in expected]}")
            dut._log.info(f"Got:      {[hex(b) for b in output_bytes]}")
            raise TestFailure(f"Test {i}: Output mismatch")
        
        dut._log.info(f"Test {i} passed")
        
        # Wait one more cycle before next test
        await RisingEdge(dut.clk)
    
    dut._log.info(f"\nAll {len(test_cases)} tests passed!")
