import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
import numpy as np

@cocotb.test()
async def test_scavenger(dut):
    # Generate clock
    clock = cocotb.clock.Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Test case 1: n=3 scaled to n=4 (add dummy task)
    test_in1 = {
        "total_time": 352,
        "travel_matrix": [
            0,   70,  66,  71,  97, 0, 
            76,  0,   87,  66,  74, 0, 
            62,  90,  0,   60,  94, 0, 
            60,  68,  68,  0,   69, 0, 
            83,  78,  83,  73,  0,  0, 
            0,   0,   0,   0,   0,  0  
        ],
        "p_i": [93, 92, 99, 0],
        "t_i": [82, 76, 62, 0],
        "d_i": [444,436,0x7FF,0x7FF]
    }
    
    # Expected output (task2 only)
    exp_points1 = 99
    exp_mask1 = 0b0100
    
    # Test case 2: Original n=5, scaled to n=4 (use first 4 tasks)
    test_in2 = {
        "total_time": 696,
        "travel_matrix": [
            0, 67, 80, 81, 60, 83, 61,
            72, 0, 99, 68, 85, 93, 82,
            100,91, 0, 88,99,70, 68,
            69,65,77, 0, 65,68,75,
            63,65,91,96,0,92,100,
            65,76,85,62,89,0,75,
            93,83,74,65,88,84,0
        ][:36], 
        "p_i": [96,99,96,90],
        "t_i": [88,70,66,92],
        "d_i": [532,519,637,592]
    }
    exp_points2 = 96+99+96 = 291
    exp_mask2 = 0b0111 # Tasks 0,1,2
    
    test_cases = [
        (test_in1, exp_points1, exp_mask1),
        (test_in2, exp_points2, exp_mask2)
    ]
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    passed = 0
    for idx, (test_in, exp_pts, exp_mask) in enumerate(test_cases):
        # Load inputs
        dut.total_time.value = test_in["total_time"]
        for i in range(6*6):
            dut.travel_matrix[i].value = test_in["travel_matrix"][i] if i < len(test_in["travel_matrix"]) else 0
        for i in range(4):
            dut.p_i[i].value = test_in["p_i"][i]
            dut.t_i[i].value = test_in["t_i"][i]
            dut.d_i[i].value = test_in["d_i"][i]
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (16 cycles)
        await ClockCycles(dut.clk, 16)
        
        # Verify outputs
        if dut.done.value == 1 and dut.max_points.value == exp_pts and dut.task_set.value == exp_mask:
            passed += 1
        else:
            dut._log.error(f"Test {idx} failed: MaxP {dut.max_points.value} (exp {exp_pts}), Mask {bin(dut.task_set.value)} (exp {exp_mask})")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)