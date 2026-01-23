import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure

# Helper function to check if value is defined
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

async def send_char(dut, char, timeout_ns=1000):
    """Send a single character to the DUT and wait for it to be consumed."""
    ascii_val = ord(char)
    dut.char_in.value = ascii_val
    dut.valid_in.value = 1
    
    # Wait for a clock cycle to capture the input
    await RisingEdge(dut.clk)
    
    # De-assert valid_in
    dut.valid_in.value = 0
    
    # Small delay to allow processing
    await Timer(10, units='ns')

@cocotb.test(timeout_time=1000, timeout_unit='ms')
async def test_bracket_validator(dut):
    """Test the bracket validator module."""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_in.value = 0
    dut.char_in.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Helper to wait for done
    async def wait_for_done():
        for _ in range(20):  # Wait max 20 cycles
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and dut.done.value == 1:
                return
        raise TestFailure("Timeout waiting for done signal")
    
    # Helper to run a test case
    async def run_test(test_str, expected, test_name):
        dut._log.info(f"Testing: {test_name} - String: '{test_str}'")
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Send string
        for char in test_str:
            await send_char(dut, char)
            await RisingEdge(dut.clk) # Allow processing
            
        # Wait for completion (send stop condition by holding valid_in low)
        # We need to let the DUT know we are done sending characters.
        # Since valid_in is low, it should check stack status after timeout or count.
        # Based on the prompt, we need to wait for the module to finish processing.
        # We'll wait a few cycles for it to finalize.
        
        for _ in range(10):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and dut.done.value == 1:
                break
        
        # Check result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"{test_name}: Result is undefined")
            
        actual = int(dut.result.value)
        if actual != expected:
            raise TestFailure(f"{test_name}: Expected {expected}, got {actual}")
            
        dut._log.info(f"{test_name}: Passed")
        
        # Wait for done to go low if it stays high (optional)
        await RisingEdge(dut.clk)

    # Test cases adapted from Python
    # Note: ASCII '<' is 60 (0x3C), '>' is 62 (0x3E)
    
    tests = [
        ("<", 0, "Single open"),
        ("<>", 1, "Simple pair"),
        ("<<><>>", 1, "Nested"),
        ("><<>", 0, "Wrong order"),
        ("<><><<><>><>", 1, "Complex valid"),
        ("<><><<><>><>>", 0, "Extra close"),
        ("<<<><>>>>", 0, "Too many closes"),
        ("<<<<", 0, "All open"),
        (">", 0, "Single close"),
        ("<<>", 0, "Unclosed"),
        ("<><><<><>><>><<>", 0, "Unclosed end"),
        ("<><><<><>><>>><>", 0, "Extra close in middle"),
    ]
    
    passed = 0
    total = len(tests)
    
    for s, exp, name in tests:
        try:
            await run_test(s, exp, name)
            passed += 1
        except TestFailure as e:
            dut._log.error(str(e))
        await Timer(50, units='ns') # Reset settling
        
    dut._log.info(f"\nSummary: {passed}/{total} tests passed")
    if passed != total:
        raise TestFailure(f"Failed {total - passed} tests")