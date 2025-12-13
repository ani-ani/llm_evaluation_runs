import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_cube(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        ([1, 2, 3, 4], [1, 8, 27, 64], "Small values"),
        ([10, 20, 30, 0], [1000, 8000, 27000, 0], "Medium values with zero"),
        ([12, 15, 0, 0], [1728, 3375, 0, 0], "Edge cases with zero padding")
    ]
    
    passed = 0
    for inputs, expected, desc in test_cases:
        # Pack inputs into 20-bit vector
        packed_input = 0
        for i, val in enumerate(inputs):
            packed_input |= (val & 0x1F) << (i*5)
        
        dut.nums.value = packed_input
        await RisingEdge(dut.clk)
        
        # Verify results
        errors = []
        for i in range(4):
            got = dut.cubes.value >> (i*15) & 0x7FFF  # Extract 15-bit chunk
            exp = expected[i] if i < len(expected) else 0
            if got != exp:
                errors.append(f"Element {i}: Got {got} Expected {exp}")
        
        if len(errors) == 0:
            passed += 1
            dut._log.info(f"PASS: {desc} {inputs} -> {expected}")
        else:
            dut._log.error(f"FAIL {desc}:
{'; '.join(errors)}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)