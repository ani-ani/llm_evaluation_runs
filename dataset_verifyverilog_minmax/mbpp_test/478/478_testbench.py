import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_lowercase_filter(dut):
    # Generate clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases (padded to 8 bytes with nulls)
    test_cases = [
        (b"PYTHon\\x00\\x00", b"PYTH\\x00\\x00\\x00\\x00", 4),
        (b"FInD\\x00\\x00\\x00\\x00", b"FID\\x00\\x00\\x00\\x00\\x00", 3),
        (b"STRinG\\x00\\x00", b"STRG\\x00\\x00\\x00\\x00", 4),
        (b"abcdEFGH", b"EFGH\\x00\\x00\\x00\\x00", 4),
        (b"NO_LOWER", b"NO_LOWER", 8)
    ]
    
    passed = 0
    for input_str, expected_output, expected_len in test_cases:
        # Load input
        dut.str_in.value = int.from_bytes(input_str, byteorder='big')
        
        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        for _ in range(9):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        
        # Verify outputs
        out_bytes = bytes.fromhex(f"{dut.str_out.value.integer:016x}")
        is_valid = (out_bytes == expected_output and dut.valid_len.value == expected_len)
        
        if is_valid:
            passed += 1
            dut._log.info(f"PASS: {input_str}→{expected_output} (len={expected_len})")
        else:
            dut._log.error(f"FAIL: {input_str}→{out_bytes} (len={dut.valid_len.value}) "
                          f"expected {expected_output} (len={expected_len})")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed.")