import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_reverse_words(dut):
    # Create 10ns period clock
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    
    # Test cases (ASCII hex values)
    test_cases = [
        (b"python pro    ", b"pro    python"),  # "python pro" -> "pro python"
        (b"java lang    ", b"lang    java"),   # "java lang" -> "lang java"
        (b"indian man   ", b"man   indian"),  # "indian man" -> "man indian"
        (b"singleword   ", b"singleword   "), # No reversal needed
        (b"a b c d      ", b"d      c b a")  # Multiple words
    ]
    
    passed = 0
    for input_str, expected in test_cases:
        # Wait for idle state
        while dut.done.value != 1:
            await RisingEdge(dut.clk)
        
        # Apply input
        dut.str.value = int.from_bytes(input_str, 'big')
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while dut.done.value == 0:
            await RisingEdge(dut.clk)
        
        # Check result
        result = dut.reversed_str.value.integer.to_bytes(16, 'big')
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: Input '{input_str.decode().strip()}' -> '{result.decode().strip()}'")
        else:
            dut._log.error(f"FAIL: Input '{input_str.decode().strip()}'. Got '{result.decode().strip()}'. Expected '{expected.decode().strip()}'")
    
    # Final report
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)