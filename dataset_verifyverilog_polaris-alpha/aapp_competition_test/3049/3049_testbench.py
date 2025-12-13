import cocotb
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_sub_cipher(dut):
    # Create clock generator (100MHz)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Test cases (msg, fragment, expected_count)
    test_cases = [
        # Scaled-down test case 1
        ("sercboot", "boot", 1), # Original: secretmessage boot→essa
        # Matching positions
        ("abcdabcdabcdabcd", "abcd", 13),
        # No match
        ("orangesaregood", "apple", 0),
        # Multiple matches
        ("aaaaaaaaaaaaaaaa", "aaaa", 13)
    ]

    # Helper to convert string to bit vector
    def str_to_bits(s, max_len):
        val = 0
        s = s.ljust(max_len, '\\\u0000')
        for i,c in enumerate(s[:max_len]):
            char_val = ord(c) - ord('a') if c != '\\\u0000' else 31
            val |= (char_val & 0x1f) << (5*i)
        return val

    passed = 0
    dut._log.info("Starting tests")
    for msg, frag, expected in test_cases:
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Apply inputs
        dut.encrypted_msg.value = str_to_bits(msg, 16)
        dut.fragment.value = str_to_bits(frag, 4)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait until done (max 16 cycles)
        cycles = 0
        while not dut.done.value and cycles < 20:
            await RisingEdge(dut.clk)
            cycles += 1
        
        if cycles >= 20:
            dut._log.error("Timeout waiting for done")
        else:
            if dut.count.value == expected:
                passed +=1
                dut._log.info(f"Test passed: {msg} | {frag} → {dut.count.value}")
            else:
                dut._log.error(f"Test failed: {msg} | {frag}, got {dut.count.value}, expected {expected}")
        
        # Reset between tests
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
