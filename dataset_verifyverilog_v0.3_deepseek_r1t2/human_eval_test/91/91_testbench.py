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

# Character constants
CHAR_I = 0x49
CHAR_DOT = 0x2E
CHAR_QMARK = 0x3F
CHAR_EXCLAIM = 0x21
CHAR_NULL = 0x00

@cocotb.test(timeout_time=500, timeout_unit='ms')
async def test_is_bored(dut):
    """Test the is_bored module with various sentences."""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid.value = 0
    dut.char_in.value = 0
    dut.char_index.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Helper to execute a test case
    async def run_test(test_string, expected, test_name):
        dut._log.info(f"Running {test_name}: '{test_string}'")
        
        # Pad string to 64 characters with nulls
        chars = list(test_string.encode('ascii'))
        chars = chars[:64]  # Max 64 characters
        while len(chars) < 64:
            chars.append(CHAR_NULL)
        
        # Reset state for new test
        dut.start.value = 0
        await RisingEdge(dut.clk)
        
        # Start the computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Now we need to simulate the memory read cycle
        # The module will set read_index, we provide char_in on next cycle
        
        done_detected = False
        result_value = 0
        
        # Process for enough cycles (max 70 for 64 chars + overhead)
        for cycle in range(70):
            await RisingEdge(dut.clk)
            await Timer(1, units='ns')  # Small delay for combo logic
            
            # Check if module is requesting a character
            if is_value_defined(dut.read_index.value):
                read_idx = int(dut.read_index.value)
                if read_idx < 64:
                    dut.char_in.value = chars[read_idx]
                    dut.valid.value = 1
                    dut.char_index.value = read_idx
                else:
                    dut.char_in.value = CHAR_NULL
                    dut.valid.value = 0
            
            # Check for done signal
            if is_value_defined(dut.done.value) and dut.done.value == 1:
                if not done_detected:
                    # Sample result
                    if is_value_defined(dut.result.value):
                        result_value = int(dut.result.value)
                    else:
                        raise TestFailure(f"{test_name}: Result is undefined when done is high")
                    done_detected = True
                    break
        
        if not done_detected:
            raise TestFailure(f"{test_name}: Done signal not asserted within timeout")
        
        if result_value != expected:
            raise TestFailure(f"{test_name}: Expected {expected}, got {result_value}")
        
        dut._log.info(f"{test_name}: PASSED (result={result_value})")
        return True
    
    # Test cases
    test_cases = [
        ("Hello world", 0, "Test_1"),
        ("Is the sky blue?", 0, "Test_2"),
        ("I love It !", 1, "Test_3"),
        ("bIt", 0, "Test_4"),
        ("I feel good today. I will be productive. will kill It", 2, "Test_5"),
        ("You and I are going for a walk", 0, "Test_6"),
        ("I", 1, "Test_7_I_alone"),
        (".I", 1, "Test_8_dot_before_I"),
        ("I.I", 2, "Test_9_two_sentences"),
        ("", 0, "Test_10_empty"),
        ("i am small", 0, "Test_11_lowercase_i"),
        ("!!I? I?", 2, "Test_12_multiple_delims"),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for test_string, expected, test_name in test_cases:
        try:
            await run_test(test_string, expected, test_name)
            passed += 1
        except TestFailure as e:
            dut._log.error(str(e))
    
    dut._log.info(f"\nResults: {passed}/{total} tests passed")
    
    if passed < total:
        raise TestFailure(f"Failed {total - passed} test(s)")

@cocotb.test(timeout_time=100, timeout_unit='ms')
async def test_reset_behavior(dut):
    """Test that reset properly initializes the module."""
    
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Apply reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    
    # Check that result is 0 after reset
    if is_value_defined(dut.result.value):
        if int(dut.result.value) != 0:
            raise TestFailure(f"Reset failed: result={int(dut.result.value)}, expected 0")
    
    # Check that done is 0 after reset
    if is_value_defined(dut.done.value):
        if dut.done.value != 0:
            raise TestFailure(f"Reset failed: done={int(dut.done.value)}, expected 0")
    
    dut._log.info("Reset behavior test: PASSED")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)