import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_snake_camel(dut):
    # Test cases with (input_str, output_str, length)
    test_cases = [
        # Test 1 (Original: 'python_program' → 'PythonProgram')
        (b"python_prog", b"PythonProg", 10),
        # Test 2 (Original: 'python_language' → 'PythonLanguage')
        (b"python_lang", b"PythonLang", 10),
        # Test 3 (Original: 'programming_language' → 'ProgrammingLanguage')
        (b"program_lan", b"ProgramLan", 10),
        # Additional edge cases
        (b"a_b", b"AB", 3),        # Minimal case
        (b"_leading", b"Leading", 8) # Underscore at start
    ]
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    passed = 0
    for input_bytes, expected_output, length in test_cases:
        # Pad inputs to 10 bytes
        padded_input = input_bytes.ljust(10, b'\\0')
        padded_expected = expected_output.ljust(10, b'\\0')
        
        # Apply inputs
        dut.snake_str.value = int.from_bytes(padded_input, byteorder='big')
        dut.length.value = length
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait 11 cycles (processing + done)
        for _ in range(11):
            await RisingEdge(dut.clk)
        
        # Check output
        result_bytes = dut.camel_str.value.buffered_value.to_bytes(10, 'big')
        exp_bytes = padded_expected
        
        if result_bytes == exp_bytes and dut.done.value == 1:
            passed += 1
            dut._log.info(f"PASS: {input_bytes} → {result_bytes}")
        else:
            dut._log.error(f"FAIL: {input_bytes} → {result_bytes}, expected {exp_bytes}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")