import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_swaps(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    test_cases = [
        # Input compartments          Expected output
        ([1,2,2,4,3,0,0,0],          2),
        ([4,1,1,0,0,0,0,0],           2),
        ([0,3,0,4,0,0,0,0],           0),
        ([1,1,1,0,0,0,0,0],           2),  # Invalid case: sum=3 but needs swaps
        ([4,4,4,4,0,0,0,0],           0),  # All valid
        ([1,1,1,1,1,1,1,1],           6)   # 8 ones
    ]
    passed = 0
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    for compartments, expected in test_cases:
        # Apply inputs
        dut.start.value = 0
        for i in range(8):
            dut.__dict__[f"comp{i}"].value = compartments[i]
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check result
        actual = dut.result.value
        if actual == expected:
            passed += 1
        else:
            dut._log.error(f"Failed: {compartments} Expected={expected}, Got={actual}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
