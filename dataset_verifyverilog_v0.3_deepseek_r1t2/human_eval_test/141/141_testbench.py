import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure

# Helper function to check if value is defined (not X or Z)
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_file_name_check(dut):
    """
    Test the file_name_check module with various filename strings.
    Each test case is processed as a 16-character fixed-width string.
    """
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_char.value = 0
    dut.char_in.value = 0
    dut.char_idx.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (input_string, expected_result)
    # Expected: 1 = Yes, 0 = No
    test_cases = [
        ("example.txt", 1),
        ("1example.dll", 0),
        ("s1sdf3.asd", 0),
        ("K.dll", 1),
        ("MY16FILE3.exe", 1),
        ("His12FILE94.exe", 0),
        ("_Y.txt", 0),
        ("?aREYA.exe", 0),
        ("/this_is_valid.dll", 0),
        ("this_is_valid.wow", 0),
        ("this_is_valid.txt", 1),
        ("this_is_valid.txtexe", 0),
        ("#this2_i4s_5valid.ten", 0),
        ("@this1_is6_valid.exe", 0),
        ("this_is_12valid.6exe4.txt", 0),
        ("all.exe.txt", 0),
        ("I563_No.exe", 1),
        ("Is3youfault.txt", 1),
        ("no_one#knows.dll", 1),
        ("1I563_Yes3.exe", 0),
        ("I563_Yes3.txtt", 0),
        ("final..txt", 0),
        ("final132", 0),
        ("_f4indsartal132.", 0),
        (".txt", 0),
        ("s.", 0),
    ]
    
    passed = 0
    failed = 0
    
    for i, (filename, expected_int) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}: Testing '{filename}' (expected {'Yes' if expected_int else 'No'})")
        
        # Pad to 16 characters with null bytes (ASCII 0)
        padded = filename.ljust(16, '\x00')
        
        # Start pulse
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Feed 16 characters
        for idx in range(16):
            char = padded[idx]
            dut.char_in.value = ord(char)
            dut.char_idx.value = idx
            dut.valid_char.value = 1
            await RisingEdge(dut.clk)
            
        # Wait for processing
        dut.valid_char.value = 0
        
        # Wait for done signal (with timeout)
        done_received = False
        for cycle in range(10):
            if is_value_defined(dut.done.value):
                if dut.done.value == 1:
                    done_received = True
                    break
            await RisingEdge(dut.clk)
        
        if not done_received:
            dut._log.error(f"Test {i+1}: Done signal not received")
            failed += 1
            continue
            
        # Verify output is defined
        if not is_value_defined(dut.result.value):
            dut._log.error(f"Test {i+1}: Result is undefined (X/Z)")
            failed += 1
            continue
            
        actual_result = int(dut.result.value)
        
        if actual_result == expected_int:
            dut._log.info(f"Test {i+1}: PASSED")
            passed += 1
        else:
            dut._log.error(f"Test {i+1}: FAILED - Expected {expected_int}, got {actual_result}")
            failed += 1
            
        # Small gap between tests
        await Timer(50, units='ns')
    
    dut._log.info(f"\nSummary: {passed}/{len(test_cases)} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed out of {len(test_cases)}")