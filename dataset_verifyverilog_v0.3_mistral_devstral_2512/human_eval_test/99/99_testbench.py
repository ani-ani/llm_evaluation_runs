import cocotb
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

async def send_string(dut, test_string):
    """Send string character by character to the module."""
    # Send each character
    for i, char in enumerate(test_string):
        dut.char_index.value = i
        dut.char_in.value = ord(char)
        dut.valid_char.value = 1
        await RisingEdge(dut.clk)
    
    # Signal end of string
    dut.valid_char.value = 0
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_closest_integer(dut):
    """Test the closest_integer module."""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_char.value = 0
    dut.char_in.value = 0
    dut.char_index.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (input_string, expected_result)
    test_cases = [
        ("10", 10),
        ("14.5", 15),
        ("-15.5", -16),
        ("15.3", 15),
        ("0", 0),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (input_str, expected) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}: Input='{input_str}', Expected={expected}")
        
        # Reset for each test
        dut.start.value = 0
        await RisingEdge(dut.clk)
        
        # Send the string
        await send_string(dut, input_str)
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (max 50 cycles)
        done_seen = False
        for cycle in range(50):
            await RisingEdge(dut.clk)
            if not is_value_defined(dut.done.value):
                continue
            if dut.done.value == 1:
                done_seen = True
                break
        
        if not done_seen:
            raise TestFailure(f"Test {i+1}: Timeout waiting for done signal")
        
        # Check for error
        if not is_value_defined(dut.error.value):
            raise TestFailure(f"Test {i+1}: Error signal is undefined")
        if dut.error.value == 1:
            raise TestFailure(f"Test {i+1}: Module reported error for valid input")
        
        # Get result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {i+1}: Result is undefined (X/Z)")
        
        result = int(dut.result.value)
        # Handle signed conversion
        if result >= 32768:
            result = result - 65536
        
        dut._log.info(f"Test {i+1}: Got {result}")
        
        if result != expected:
            raise TestFailure(f"Test {i+1}: Expected {expected}, got {result}")
        
        passed += 1
        await RisingEdge(dut.clk)
    
    dut._log.info(f"\nSummary: {passed}/{total} tests passed")
