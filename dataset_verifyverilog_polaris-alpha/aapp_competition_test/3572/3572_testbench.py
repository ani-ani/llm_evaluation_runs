import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import itertools

@cocotb.test()
async def test_race_checker(dut):
    # Generate clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Define test cases (n=4 only)
    test_cases = [
        {
            "L": 10,
            "matrix": [
                [0, 3, 2, 1],
                [3, 0, 1, 3],
                [2, 1, 0, 2],
                [1, 3, 2, 0]
            ],
            "expected": 1
        },
        {
            "L": 100, # Impossible case
            "matrix": [
                [0, 1, 2, 3],
                [1, 0, 4, 5],
                [2, 4, 0, 6],
                [3, 5, 6, 0]
            ],
            "expected": 0
        }
    ]
    
    passed = 0
    for test in test_cases:
        # Reset
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load inputs
        dut.start.value = 0
        dut.L.value = test["L"]
        for i in range(4):
            for j in range(4):
                dut.dist_matrix[i][j].value = test["matrix"][i][j]
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait until done
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check result
        if dut.result.value == test["expected"]:
            passed += 1
        else:
            ut._log.error(f"Test failed: L={test['L']} Expected {test['expected']} Got {dut.result.value}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
