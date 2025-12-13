import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_ab_pattern_check(dut):
    # Generate clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())

    async def reset():
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        await Timer(5, units='ns')
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

    # Test cases: (input_string, expected_result)
    # Strings padded with null bytes (0x00) to 8 characters
    test_cases = [
        (bytes([0x61,0x63,0,0,0,0,0,0]), False),   # "ac"
        (bytes([0x64,0x63,0,0,0,0,0,0]), False),   # "dc"
        (bytes([0x61,0x62,0x62,0x62,0x62,0x61,0,0]), True), # "abbbba"
        (bytes([0x61,0x62,0x62,0,0,0,0,0]), True),   # "abb"
        (bytes([0x61,0x62,0,0,0,0,0,0]), False),    # "ab" (too short)
        (bytes([0x61,0x62,0x62,0x62,0x63,0,0,0]), True), # "abbbc"
        (bytes([0x01,0x61,0x62,0x62,0,0,0,0]), True), # Embedded match
        (bytes([0x62,0x62,0x62,0x62,0x61,0x61,0,0]), False) # No 'a' preceding
    ]

    passed = 0
    await reset()

    for idx, (test_bytes, expected) in enumerate(test_cases):
        # Convert bytes to 64-bit integer
        int_val = int.from_bytes(test_bytes, 'big')
        dut.str_in.value = int_val

        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait until done
        while not dut.done.value:
            await RisingEdge(dut.clk)

        # Check result
        if dut.match_found.value == expected:
            passed += 1
            dut._log.info(f"Test {idx+1}: PASS (Input: {test_bytes} Expected: {expected})")
        else:
            dut._log.error(f"Test {idx+1}: FAIL (Input: {test_bytes} Result: {dut.match_found.value} Expected: {expected})")
        
        # Reset for next test
        await reset()

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")