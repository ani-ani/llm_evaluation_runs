import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
import math

@cocotb.test()
async def test_widget_packing(dut):
    # Clock generation
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        (47, 1),
        (523, 2),
        (100, 4),  # Manual computed case
        (248, 4)   # Additional test case
    ]
    
    passed = 0
    for (input_n, expected) in test_cases:
        dut.N.value = input_n
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for computation (32 cycles)
        await ClockCycles(dut.clk, 32)
        
        if dut.done.value != 1:
            dut._log.error("Done signal not asserted")
        
        result = dut.empty_squares.value.integer
        if result == expected:
            passed += 1
            dut._log.info(f"Test passed: N={input_n} Result={result}")
        else:
            dut._log.error(f"Test failed: N={input_n} Got={result}, Expected={expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)