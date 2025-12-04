import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_ab_matcher(dut):
    # Generate clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    
    # Define test cases: (input_string, expected_result)
    test_cases = [
        ("ac", False),   # should fail (c after a)
        ("dc", False),   # no a present
        ("abba", True), # contains ab
        ("a", False),   # missing b
        ("ab", True),   # exact match
        ("abb", True)   # multiple bs
    ]
    
    passed = 0
    for data_string, expected in test_cases:
        # Start pulse
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Send characters
        for c in data_string.encode('ascii'):
            dut.valid.value = 1
            dut.data.value = c
            await RisingEdge(dut.clk)
        
        # End of string
        dut.valid.value = 0
        done = False
        
        # Wait for completion (max 16 cycles + 1)
        for _ in range(len(data_string) + 2):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                done = True
                break
        
        if not done:
            dut._log.error(f"Test timed out for input: {data_string}")
            continue
        
        if dut.match.value == expected:
            passed += 1
            dut._log.info(f"PASS: '{data_string}' -> {expected}")
        else:
            dut._log.error(f"FAIL: '{data_string}' -> got {dut.match.value}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)