import cocotb
from cocotb.triggers import RisingEdge, Timer, ClockCycles
from cocotb.clock import Clock
import numpy as np

@cocotb.test()
async def test_laser_checker(dut):
    # Create clock (10ns period)
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    # Test cases (x,y in -16 to 15 range scaled from original)
    tests = [
        {
            "x": [-1, 0, 1, -1, 0, 1],  # Original: (-1,0), (0,0), (1,0), (-1,1), (0,2), (1,1)
            "y": [0, 0, 0, 1, 2, 1],    # Expected outcome: failure
            "expected": 0
        },
        { # Success case
            "x": [1,3,0,1,5,0],  # Original: (1,1)(3,5)(0,-1)(1,0)(5,0)(0,0)
            "y": [1,5,-1,0,0,0], # Line1: y=0, Line2: x+2y=3
            "expected": 1
        },
        { # Special failure case
            "x": [6,3,0,1,6,0],  # Original: (6,1),(3,5),(0,-1),(1,0),(6,0),(0,0)
            "y": [1,5,-1,0,0,0], # Not aligned on two lines
            "expected": 0
        }
    ]
    
    passed = 0
    await Timer(5, units="ns")
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    
    for test in tests:
        # Load test data
        dut.start.value = 0
        for i in range(6):
            dut.x_coords[i].value = test["x"][i] if test["x"][i] >=0 else (32 + test["x"][i]) % 32  # Handle 2's complement 
            dut.y_coords[i].value = test["y"][i] if test["y"][i] >=0 else (32 + test["y"][i]) % 32
        await RisingEdge(dut.clk)
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        # Wait for done
        while dut.done.value == 0:
            await RisingEdge(dut.clk)
        # Check result
        if dut.success.value == test["expected"]:
            passed += 1
            dut._log.info(f"Test passed: Expected {test['expected']}")
        else:
            dut._log.error(f"Test failed: Points {test['x']}, {test['y']} | Got {dut.success.value}, expected {test['expected']}")
        await Timer(10, units="ns")
    
    dut._log.info(f"Test summary: {passed}/{len(tests)} tests passed")