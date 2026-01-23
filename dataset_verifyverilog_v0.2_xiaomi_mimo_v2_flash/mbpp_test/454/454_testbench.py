import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

@cocotb.test()
async def test_wordz_matcher(dut):
    """Test wordz_matcher module with various test cases"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_in.value = 0
    dut.char_in.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Helper function to send string
    async def send_string(s):
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        for char in s:
            dut.valid_in.value = 1
            dut.char_in.value = ord(char)
            await RisingEdge(dut.clk)
        
        # Send 16 - len(s) dummy chars to complete
        for _ in range(16 - len(s)):
            dut.valid_in.value = 1
            dut.char_in.value = ord(' ')
            await RisingEdge(dut.clk)
        
        dut.valid_in.value = 0
        
        # Wait for done
        for _ in range(20):
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)
    
    # Test 1: "pythonz." should match
    dut._log.info("Test 1: pythonz.")
    await send_string("pythonz.")
    await RisingEdge(dut.clk)
    if dut.match.value != 1:
        raise TestFailure(f"Test 1 failed: expected match=1, got {dut.match.value}")
    dut._log.info("Test 1 passed")
    
    # Reset for next test
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 2: "xyz." should match
    dut._log.info("Test 2: xyz.")
    await send_string("xyz.")
    await RisingEdge(dut.clk)
    if dut.match.value != 1:
        raise TestFailure(f"Test 2 failed: expected match=1, got {dut.match.value}")
    dut._log.info("Test 2 passed")
    
    # Reset for next test
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 3: "  lang  ." should NOT match
    dut._log.info("Test 3:   lang  .")
    await send_string("  lang  .")
    await RisingEdge(dut.clk)
    if dut.match.value != 0:
        raise TestFailure(f"Test 3 failed: expected match=0, got {dut.match.value}")
    dut._log.info("Test 3 passed")
    
    # Reset for additional tests
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 4: "foo bar baz" should NOT match
    dut._log.info("Test 4: foo bar baz")
    await send_string("foo bar baz")
    await RisingEdge(dut.clk)
    if dut.match.value != 0:
        raise TestFailure(f"Test 4 failed: expected match=0, got {dut.match.value}")
    dut._log.info("Test 4 passed")
    
    # Reset for next test
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 5: "aZb" should match (uppercase Z)
    dut._log.info("Test 5: aZb")
    await send_string("aZb")
    await RisingEdge(dut.clk)
    if dut.match.value != 1:
        raise TestFailure(f"Test 5 failed: expected match=1, got {dut.match.value}")
    dut._log.info("Test 5 passed")
    
    # Reset for next test
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 6: "quick brown fox" should NOT match
    dut._log.info("Test 6: quick brown fox")
    await send_string("quick brown fox")
    await RisingEdge(dut.clk)
    if dut.match.value != 0:
        raise TestFailure(f"Test 6 failed: expected match=0, got {dut.match.value}")
    dut._log.info("Test 6 passed")
    
    # Summary
    dut._log.info("All tests completed successfully!")
