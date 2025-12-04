import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock

@cocotb.test()
async def test_max_run(dut):
    # Pad test strings to 16 characters with 'a'
    test_cases = [
        (b'GeMKSForGERksISB', 5),  # Original: 'GeMKSForGERksISBESt' (keep first 16 chars)
        (b'PrECIOusMOVemENT', 6),  # Original: 'PrECIOusMOVemENTSYT'
        (b'GooGLEFluTTERaaaa', 4) # Original: 'GooGLEFluTTER' + 4x'a'
    ]
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    passed = 0
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    for test_str, expected in test_cases:
        # Wait until module is ready
        while dut.done.value != 1:
            await RisingEdge(dut.clk)
        
        # Convert string to 128-bit vector
        str_val = int.from_bytes(test_str, byteorder='big')
        dut.str.value = str_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for processing to complete
        await ClockCycles(dut.clk, 16)
        await RisingEdge(dut.clk)
        
        # Verify output
        if dut.max_run.value == expected:
            passed += 1
            dut._log.info(f"PASS: String {test_str} ==> {dut.max_run.value}")
        else:
            dut._log.error(f"FAIL: String {test_str} => {dut.max_run.value}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")