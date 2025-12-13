import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock

@cocotb.test()
async def test_space_replacer(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    async def reset():
        dut.rst_n.value = 0
        await ClockCycles(dut.clk, 2)
        dut.rst_n.value = 1

    # Helper to convert string to 128-bit vector
    def str_to_bits(s):
        padded = s.ljust(16, '\\0')
        return int.from_bytes(padded.encode('ascii'), 'big')
    
    # Helper to convert bits to string
    def bits_to_str(bits):
        bytes_val = bits.value.to_bytes(16, 'big')
        return bytes_val.decode('ascii').rstrip('\\x00')

    test_cases = [
        ("Example        ", "Example"),
        ("Mudasir Hanif  ", "Mudasir_Hanif_"),
        ("Yellow Yellow  Dirty  Fellow", "Yellow_Yellow__Dirty__Fellow"),
        ("Exa   mple     ", "Exa-mple"),
        ("   Exa 1 2 2 mple", "-Exa_1_2_2_mple")
    ]

    passed = 0
    await reset()
    
    for input_str, expected_str in test_cases:
        # Apply test vector
        dut.text_in.value = str_to_bits(input_str)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for processing to complete
        await ClockCycles(dut.clk, 18)
        
        # Verify output
        actual = bits_to_str(dut.text_out)
        assert_msg = f"Input: '{input_str}' Expected: '{expected_str}' Actual: '{actual}'"
        
        if actual == expected_str:
            passed += 1
            dut._log.info(f"PASS: {assert_msg}")
        else:
            dut._log.error(f"FAIL: {assert_msg}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)