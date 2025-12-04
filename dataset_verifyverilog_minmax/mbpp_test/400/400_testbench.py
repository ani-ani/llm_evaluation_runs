import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_unique(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Generate test cases (packed, expected)
    test_cases = [
        # Test 1 (Original Test 1): [(3,4),(1,2),(4,3),(5,6)] => 3 unique
        (0x3_4_1_2_4_3_5_6, 3),
        # Test 2: [(4,15),(2,3),(5,4),(6,7)] => 4 unique
        (0x4_F_2_3_5_4_6_7, 4),
        # Test with duplicates: [(1,2),(2,1),(3,4),(1,2)] => 2 unique
        (0x1_2_2_1_3_4_1_2, 2),
        # All identical: [(6,6),(6,6),(6,6),(6,6)] => 1 unique
        (0x6_6_6_6_6_6_6_6, 1)
    ]
    
    passed = 0
    for (data_in, expected) in test_cases:
        # Reset
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        dut.start.value = 0
        dut.data.value = 0
        await RisingEdge(dut.clk)
        
        # Load data and start
        dut.data.value = data_in
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        for _ in range(6):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        
        # Check result
        actual = dut.unique_count.value.integer
        if actual == expected:
            passed += 1
            dut._log.info(f"PASS: Data=0x{data_in:08x} Expected={expected} Got={actual}")
        else:
            dut._log.error(f"FAIL: Data=0x{data_in:08x} Expected={expected} Got={actual}")
        
    dut._log.info(f"Test Summary: {passed}/{len(test_cases)} passed")