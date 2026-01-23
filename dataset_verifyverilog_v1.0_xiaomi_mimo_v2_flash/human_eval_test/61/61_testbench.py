import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure

# Helper function to check for defined values
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

async def wait_for_done(dut, max_cycles=50):
    """Wait for done signal to go high."""
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            return
    raise TestFailure(f"Timeout: done signal not asserted after {max_cycles} cycles")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_correct_bracketing(dut):
    """
    Test the correct_bracketing module with various bracket strings.
    """
    # Start clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_in.value = 0
    dut.done_in.value = 0
    dut.char_in.value = 0
    await Timer(20, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Define test cases: (string, expected_result)
    # 1 = balanced (True), 0 = unbalanced (False)
    test_cases = [
        ("()", 1),
        ("(()())", 1),
        ("()()(()())()", 1),
        ("()()((()()())())(()()(()))", 1),
        ("((()())))", 0),
        (")(()", 0),
        ("(", 0),
        ("(((", 0),
        (")", 0),
        ("(()", 0),
        ("()()(()())())(()", 0),
        ("()()(()())()))()", 0),
        ("", 1),  # Edge case: empty string
        ("((((()))))", 1), # Nested
        (")(", 0) # Immediate fail
    ]
    
    passed = 0
    total = len(test_cases)
    
    dut._log.info(f"Running {total} test cases...")
    
    for i, (test_str, expected) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}: Input='{test_str}', Expected={expected}")
        
        # Start signal
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Feed characters
        for char in test_str:
            # Ensure char is valid ASCII
            dut.char_in.value = ord(char)
            dut.valid_in.value = 1
            dut.done_in.value = 0
            await RisingEdge(dut.clk)
            
            # Check for early failure if logic supports it (optional)
            # We just wait for the sequence to finish
        
        # Signal end of string
        dut.valid_in.value = 0
        dut.done_in.value = 1
        # The module might need a cycle to process the done signal
        # Or we drive done_in high for one cycle then low
        # Based on prompt: "done_in: high to indicate end of string"
        # We will keep it high for one cycle then low, or just pulse it.
        # Let's pulse it.
        await RisingEdge(dut.clk)
        dut.done_in.value = 0
        
        # Wait for done output
        await wait_for_done(dut, max_cycles=len(test_str) + 10)
        
        # Check result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {i+1}: Result is undefined (X/Z)")
        
        result = int(dut.result.value)
        
        if result == expected:
            dut._log.info(f"Test {i+1} [PASSED]: Got {result}")
            passed += 1
        else:
            dut._log.error(f"Test {i+1} [FAILED]: Got {result}, Expected {expected}")
            raise TestFailure(f"Test {i+1} Failed")
            
        # Small delay between tests
        await Timer(10, units="ns")
        
    dut._log.info(f"\nSummary: {passed}/{total} tests passed")
    if passed != total:
        raise TestFailure(f"Only {passed}/{total} passed")