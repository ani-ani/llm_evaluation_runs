import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_bracket(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Test cases: (input_string, expected_result)
    test_cases = [
        ('[[]]', True),
        ('[]]]]]]][[[[[]', False),
        ('[][]', False),
        ('[]', False),
        ('[[[[]]]]', True),
        ('[]]]]]]]]]]', False),
        ('[][][[]]', True),
        ('[[]', False),
        ('[]]', False),
        ('[[]][[', True),
        ('[[][]]', True),
        ('', False),
        ('[[[[[[[[', False),
        (']]]]]]]]', False)]
    
    passed = 0
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    for s, expected in test_cases:
        # Convert string to bit vector
        data_val = 0
        for i, c in enumerate(s):
            data_val |= (1 if c == ']' else 0) << i
        
        dut.start.value = 0
        dut.length.value = len(s)
        dut.data.value = data_val
        await RisingEdge(dut.clk)
        
        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        cycles = len(s) if len(s) > 0 else 1
        for _ in range(cycles):
            await RisingEdge(dut.clk)
        await RisingEdge(dut.done)
        
        # Check result
        if dut.result.value == expected:
            passed += 1
            dut._log.info(f"PASS: '{s}' -> {expected}")
        else:
            dut._log.error(f"FAIL: '{s}' got {dut.result.value}, expected {expected}")
        
        # Reset state between tests
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)