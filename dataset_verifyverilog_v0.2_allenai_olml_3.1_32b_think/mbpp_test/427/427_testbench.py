import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_date_format_converter(dut):
    """Test date format conversion from yyyy-mm-dd to dd-mm-yyyy"""
    
    # Create a 10MHz clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_in.value = ord('0')
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: "2026-01-02" -> "02-01-2026"
    dut._log.info("Test 1: 2026-01-02 -> 02-01-2026")
    await run_conversion(dut, "2026-01-02", "02-01-2026")
    
    # Test case 2: "2020-11-13" -> "13-11-2020"
    dut._log.info("Test 2: 2020-11-13 -> 13-11-2020")
    await run_conversion(dut, "2020-11-13", "13-11-2020")
    
    # Test case 3: "2021-04-26" -> "26-04-2021"
    dut._log.info("Test 3: 2021-04-26 -> 26-04-2021")
    await run_conversion(dut, "2021-04-26", "26-04-2021")
    
    # Additional test cases with different digits
    # Test case 4: "1999-12-31" -> "31-12-1999"
    dut._log.info("Test 4: 1999-12-31 -> 31-12-1999")
    await run_conversion(dut, "1999-12-31", "31-12-1999")
    
    # Test case 5: "2000-01-01" -> "01-01-2000"
    dut._log.info("Test 5: 2000-01-01 -> 01-01-2000")
    await run_conversion(dut, "2000-01-01", "01-01-2000")
    
    dut._log.info("All tests completed successfully!")

async def run_conversion(dut, input_date, expected_output):
    """Helper function to run a single conversion test"""
    
    # Convert strings to list of ASCII values
    input_chars = [ord(c) for c in input_date]
    expected_chars = [ord(c) for c in expected_output]
    
    # Start the conversion
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Feed input characters one per cycle
    output_chars = []
    
    for i, char_val in enumerate(input_chars):
        # Feed next input character
        dut.char_in.value = char_val
        await RisingEdge(dut.clk)
        
        # Check if output is valid during this cycle
        if dut.out_valid.value:
            output_chars.append(chr(int(dut.char_out.value)))
    
    # Continue clocking to collect remaining output characters
    # We expect 10 output characters total
    while len(output_chars) < 10:
        dut.char_in.value = ord('0')  # Dummy input
        await RisingEdge(dut.clk)
        if dut.out_valid.value:
            output_chars.append(chr(int(dut.char_out.value)))
    
    # Wait for done signal
    timeout = 0
    while not dut.done.value and timeout < 20:
        dut.char_in.value = ord('0')
        await RisingEdge(dut.clk)
        if dut.out_valid.value and len(output_chars) < 10:
            output_chars.append(chr(int(dut.char_out.value)))
        timeout += 1
    
    # Convert list to string
    result = ''.join(output_chars)
    
    # Verify
    if result != expected_output:
        raise TestFailure(f"Expected '{expected_output}', got '{result}'")
    
    dut._log.info(f"  Input: {input_date} -> Output: {result} ✓")
    
    # Small delay before next test
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)