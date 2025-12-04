import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import numpy as np

@cocotb.test()
async def water_height_test(dut):
    clock = Clock(dut.clk, 10, units="ns")  # 100MHz clock
    cocotb.start_soon(clock.start())
    # Test cases (original samples scaled to fixed-point)
    test_cases = [
        {
            "input": {"N":4, "D":30<<16, "L":50<<16, "vertices": [(20<<6,0),(100<<6,0),(100<<6,40<<6),(20<<6,40<<6)]}
            "expected": int(20.83 * 65536)
        },
        {
            "input": {"N":8, "D":30<<16, "L":70<<16, "vertices": [(110<<6,70<<6),(100<<6,80<<6),(80<<6,80<<6),(-10<<6,60<<6),(-40<<6,30<<6),(-40<<6,25<<6),(20<<6,0),(100<<6,0)]}
            "expected": int(19.74 * 65536)
        }
    ]
    passed = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    for case in test_cases:
        # Apply inputs
        dut.start.value = 0
        dut.N_vertices.value = case['input']['N']
        dut.D_depth.value = case['input']['D']
        dut.L_liters.value = case['input']['L']  
        for i in range(case['input']['N']):
            dut.vertices[i][0].value = case['input']['vertices'][i][0]
            dut.vertices[i][1].value = case['input']['vertices'][i][1]
        await RisingEdge(dut.clk)
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        # Wait for 16 cycles
        for _ in range(16):
            await RisingEdge(dut.clk)
        # Check result
        if dut.done.value == 1:
            tolerance = 10  # allow 0.005 cm error
            expected = case['expected']
            actual = dut.height.value.signed_integer
            if abs(actual - expected) <= tolerance:
                passed += 1
            else:
                actual_cm = actual / 65536.0
                expected_cm = expected / 65536.0
                dut._log.error(f"Test failed: got {actual_cm:.2f}, expected {expected_cm:.2f}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")