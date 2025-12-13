import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_robot(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset system
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases (scaled to 16-bit)
    test_cases = [
        # Input: (a, b, cmd_string), expected
        ((2, 2, [3, 0]), 1),  # 'RU' = R=11, U=00
        ((1, 2, [3, 0]), 0),   # 'RU' w/ different target
        ((0, 0, [1]), 1),      # 'D'
        ((-1, 0, [2]), 1),     # 'L'
        ((32767, 0, [3]*16), 0) // Edge case
    ]
    
    passed = 0
    for (a_val, b_val, cmd), expected in test_cases:
        # Apply inputs
        dut.a.value = a_val
        dut.b.value = b_val
        for i in range(16):
            if i < len(cmd):
                dut.cmd_string[i].value = cmd[i]
            else:
                dut.cmd_string[i].value = 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait until done
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check result
        if dut.result.value == expected:
            passed += 1
        else:
            dut._log.error(f"Failed: ({a_val},{b_val},{cmd}) = {dut.result.value}, expected {expected}")
        
        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
