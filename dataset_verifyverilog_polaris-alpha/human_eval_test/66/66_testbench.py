import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_uppercase_sum(dut):
    # Generate clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    test_cases = [
        ("", 0),
        ("abAB", 131),
        ("abcCd", 67),
        ("helloE", 69),
        ("woArBld", 131),
        ("aAaaaXa", 153),
        (" How are yOu?", 151)
    ]
    
    passed = 0
    
    def pack_string(s):
        # Pad with zeros to 16 bytes
        padded = s.ljust(16, '\\0')
        return int.from_bytes(padded.encode(), 'little')
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    
    for string, expected in test_cases:
        dut.start.value = 1
        dut.s_string.value = pack_string(string)
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal (16 cycles + 1)
        for _ in range(17):
            await RisingEdge(dut.clk)
            
        if dut.done.value == 1:
            result = dut.sum.value.integer
            if result == expected:
                passed += 1
                dut._log.info(f"PASS: '{string[:10]}' => {result}")
            else:
                dut._log.error(f"FAIL: '{string[:10]}' => {result}, expected {expected}")
        else:
            dut._log.error(f"TIMEOUT: '{string[:10]}' did not complete")
    
    # Report results
    total = len(test_cases)
    dut._log.info(f"SUMMARY: {passed}/{total} tests passed")
    # Removed test case: 'You arE Very Smart' (exceeds 16 chars)