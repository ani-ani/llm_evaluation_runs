import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import struct

@cocotb.test()
async def test_frog_jump(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Test cases (scaled)
    test_cases = [
        { # Sample input 1
            "N": 7, "K": 5, "dirs": 0b0001101110, # 'A','C','D','B','B'
            "plants": [(5,6), (8,9), (4,13), (1,10), (7,4), (10,9), (3,7)],
            "expected": (7,4)
        },
        { # Sample input 2
            "N": 6, "K": 12, "dirs": 0b0000000001011010101111, # 'A'*7,'B','C'*3,'D'*2
            "plants": [(1,1), (2,2), (3,3), (4,4), (5,3), (6,2)],
            "expected": (5,3)
        }
    ]
    passed = 0

    for case in test_cases:
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

        # Pack plants into 128-bit vectors
        px = [0]*8; py = [0]*8
        for i,p in enumerate(case["plants"]):
            px[i] = p[0]
            py[i] = p[1]
        packed_x = (px[0]<<0) | (px[1]<<16) | (px[2]<<32) | (px[3]<<48) | (px[4]<<64) | (px[5]<<80) | (px[6]<<96) | (px[7]<<112)
        packed_y = (py[0]<<0) | (py[1]<<16) | (py[2]<<32) | (py[3]<<48) | (py[4]<<64) | (py[5]<<80) | (py[6]<<96) | (py[7]<<112)

        # Apply inputs
        dut.N.value = case["N"]
        dut.K.value = case["K"]
        dut.plant_x.value = packed_x
        dut.plant_y.value = packed_y
        dut.directions.value = case["dirs"]
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait until done
        while not dut.done.value:
            await RisingEdge(dut.clk)

        # Check results
        if (dut.final_x.value == case["expected"][0] and 
            dut.final_y.value == case["expected"][1]):
            passed += 1
        else:
            dut._log.error("Test failed: Expected %d,%d Got %d,%d",
                        case["expected"][0], case["expected"][1],
                        dut.final_x.value, dut.final_y.value)

        # Reset between tests
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1

    dut._log.info("%d/%d tests passed", passed, len(test_cases))