import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
import numpy as np

@cocotb.test()
async def test_torpedo(dut):
    # Test cases scaled to n=5 and n=3
    test_cases = [
        {
            "n": 5,
            "m": 3,
            "ships": [
                (-3, -2, 3),
                (-2, -2, 4),
                (2, 5, 1)
            ],
            "expected": "--+0-",
            "possible": True
        },
        {
            "n": 3,
            "m": 2,
            "ships": [
                (1, 2, 1),
                (-2, 0, 2)
            ],
            "expected": "0+-",
            "possible": True
        },
        {
            "n": 3,
            "m": 2,
            "ships": [
                (1, 2, 1),
                (-2, 1, 2)
            ],
            "expected": ""impossible"",
            "possible": False
        }
    ]
    
    # Clock setup
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    passed = 0
    for idx, tc in enumerate(test_cases):
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await ClockCycles(dut.clk, 2)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load inputs
        dut.n_seconds.value = tc["n"]
        dut.m_ships.value = tc["m"]
        
        # Zero ships first
        for i in range(4):
            dut.ship_x1[i].value = 0
            dut.ship_x2[i].value = 0
            dut.ship_y[i].value = 0
        
        # Load ships
        for i, ship in enumerate(tc["ships"]):
            dut.ship_x1[i].value = ship[0]
            dut.ship_x2[i].value = ship[1]
            dut.ship_y[i].value = ship[2]
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        await ClockCycles(dut.clk, tc["n"]+1)
        await RisingEdge(dut.clk)
        
        # Check results
        if dut.done.value != 1:
            dut._log.error(f"Test {idx} didn't complete")
            continue
        
        if dut.possible.value != tc["possible"]:
            dut._log.error(f"Test {idx} possibility mismatch: {dut.possible.value} vs {tc['possible']}")
            continue
        
        # Check path
        valid = True
        if tc["possible"]:
            path_chars = []
            for i in range(tc["n"]):
                move = dut.path[i].value
                match move:
                    case 0: path_chars.append('-')
                    case 1: path_chars.append('0')
                    case 2: path_chars.append('+')
                    case _: path_chars.append('?')
            actual_path = ''.join(path_chars)
            if actual_path != tc["expected"]:
                dut._log.error(f"Test {idx} path mismatch: {actual_path} vs {tc['expected']}")
                valid = False
        
        if valid:
            passed += 1
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
