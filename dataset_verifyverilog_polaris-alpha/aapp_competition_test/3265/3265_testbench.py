import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import numpy as np

@cocotb.test()
async def test_t_finder(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Test cases (scaled - example only)
    test_cases = [
        { # Sample Input 1 (N=3 scaled to 4 nodes)
            "L": 1, 
            "adj_rows": [
                0x0_01_01_00, # Node1: to2=1, to3=1 (11 and 9 scaled to 1 each)
                0x0_00_01_00, # Node2: to3=1 (original 10 scaled)
                0x0_00_00_00, # Node3: no connections
                0x0_00_00_00  # Node4: none
            ],
            "expected_T": 2
        },
        { # Sample Input 2 (N=4)
            "L": 3,
            "adj_rows": [
                0x0_01_00_04, # Node1: to2=1, to4=4 (19->4)
                0x0_00_01_00, # Node2: to3=1 (original 2->1)
                0x0_05_00_01, # Node3: to2=5(original), to4=1 (3->1)
                0x0_00_00_00  # Node4: none
            ],
            "expected_T": -1
        }
    ]
    
    passed = 0
    for case in test_cases:
        # Apply reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Set inputs
        dut.L.value = case["L"]
        dut.adj_matrix_row0.value = case["adj_rows"][0]
        dut.adj_matrix_row1.value = case["adj_rows"][1]
        dut.adj_matrix_row2.value = case["adj_rows"][2]
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (max 15 cycles)
        timeout = 0
        while not dut.done.value and timeout < 20:
            await RisingEdge(dut.clk)
            timeout += 1
        
        if timeout >= 20:
            dut._log.error("Timeout")
            continue
        
        # Check result
        if dut.T_out.value.signed_integer == case["expected_T"]:
            passed += 1
        else:
            dut._log.error(f"Case failed: Expected T={case['expected_T']}, got {dut.T_out.value.signed_integer}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
