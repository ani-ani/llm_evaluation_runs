import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles
import numpy as np

@cocotb.test()
async def test_matrix_optimizer(dut):
    clock = Clock(dut.clk, 10, units="ns")  
    cocotb.start_soon(clock.start())  
    
    # Test cases adapted to 4x4 matrices
    test_matrices = [
        [[1, -2, 5, 200], [-8, 0, -4, -10], [11, 4, 0, 100], [0,0,0,0]],  # Original 3x4 padded
        [[8, -2, 7, 0], [1, 0, -3, 0], [-4, -8, 3, 0], [0,0,0,0]]   # 3x3 padded
    ]
    expected_outputs = [
        {'sum': 345, 'ops': 2}, 
        {'sum': 34, 'ops': 4}
    ]
    
    passed = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1
    
    for i, matrix in enumerate(test_matrices):
        # Load matrix (cycle 1)
        for row in range(4):
            for col in range(4):
                dut.matrix_in[row][col].value = int(matrix[row][col]) if row < len(matrix) and col < len(matrix[0]) else 0
        
        dut.start.value = 1
        await ClockCycles(dut.clk, 1)
        dut.start.value = 0
        
        # Wait 3 cycles for computation
        await ClockCycles(dut.clk, 3)
        
        # Verify outputs
        actual_sum = dut.best_sum.value.signed_integer
        actual_ops = dut.operation_count.value.integer
        
        if actual_sum == expected_outputs[i]['sum'] and actual_ops == expected_outputs[i]['ops']:
            passed += 1
        else:
            dut._log.error(f"Test {i+1} failed: Sum={actual_sum} (exp {expected_outputs[i]['sum']}), Ops={actual_ops} (exp {expected_outputs[i]['ops']})")
    
    dut._log.info(f"{passed}/{len(test_matrices)} tests passed")
    assert passed == len(test_matrices)