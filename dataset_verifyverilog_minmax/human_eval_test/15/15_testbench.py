import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import itertools

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test()
async def test_sequence(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    test_cases = [
        (0, "0"),
        (3, "0 1 2 3"),
        (10, "0 1 2 3 4 5 6 7 8 9 10"),
        (15, "0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15")
    ]

    passed = 0
    total = len(test_cases)
    
    await reset_dut(dut)
    
    for (n_val, expected_str) in test_cases:
        # Prepare test
        dut.n.value = n_val
        dut.start.value = 1
        
        # Wait for next clock
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Collect output
        output = []
        timeout = 80
        
        # Capture characters until done or timeout
        while not dut.done.value and timeout > 0:
            await RisingEdge(dut.clk)
            if dut.valid.value:
                output.append(chr(int(dut.char_out.value)))
            timeout -= 1
        
        # Build result string
        result = ''.join(output)
        
        # Validate
        if result == expected_str:
            dut._log.info(f"PASS ({n_val}): Result '{result}'")
            passed += 1
        else:
            dut._log.error(f"FAIL ({n_val}): Expected '{expected_str}', got '{result}'")
        
        # Make sure we didn't timeout
        if timeout <= 0:
            dut._log.error("Timeout waiting for done")
        
        # Reset for next test
        await reset_dut(dut)
    
    dut._log.info(f"{passed}/{total} tests passed")
    
    # Final assertion for test framework
    assert passed == total