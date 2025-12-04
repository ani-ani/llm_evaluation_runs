import cocotb
from cocotb.triggers import RisingEdge, ClockCycles, Timer
from cocotb.clock import Clock
import math

@cocotb.test()
async def test_max_path_average(dut):
    # Generate clock (100 MHz)
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Fixed-point conversion helper
    def fp(value):
        return int(round(value * 256)) & 0xFFFF
    
    # Test cases (scaled to 4x4 with Q8.8)
    tests = [
        ([[1.0, 2.0, 3.0, 0.0],
          [6.0, 5.0, 4.0, 0.0],
          [7.0, 3.0, 9.0, 0.0],
          [0.0, 0.0, 0.0, 0.0]], 5.2),
        
        ([[2.0, 3.0, 4.0, 0.0],
          [7.0, 6.0, 5.0, 0.0],
          [8.0, 4.0, 10.0, 0.0],
          [0.0, 0.0, 0.0, 0.0]], 6.2),
        
        # Edge case 1: All zeros except path
        ([[5.0, 0.0, 0.0, 0.0],
          [0.0, 5.0, 0.0, 0.0],
          [0.0, 0.0, 5.0, 0.0],
          [0.0, 0.0, 0.0, 5.0]], 5.0),
        
        # Edge case 2: Maximum value path
        ([[15.0, 1.0, 1.0, 1.0],
          [1.0, 15.0, 1.0, 1.0],
          [1.0, 1.0, 15.0, 1.0],
          [1.0, 1.0, 1.0, 15.0]], 15.0)
    ]
    
    passed = 0
    total = len(tests)
    
    for cost_matrix, expected in tests:
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await ClockCycles(dut.clk, 2)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load inputs
        dut.cost_0_0.value = fp(cost_matrix[0][0])
        dut.cost_0_1.value = fp(cost_matrix[0][1])
        dut.cost_0_2.value = fp(cost_matrix[0][2])
        dut.cost_0_3.value = fp(cost_matrix[0][3])
        dut.cost_1_0.value = fp(cost_matrix[1][0])
        dut.cost_1_1.value = fp(cost_matrix[1][1])
        dut.cost_1_2.value = fp(cost_matrix[1][2])
        dut.cost_1_3.value = fp(cost_matrix[1][3])
        dut.cost_2_0.value = fp(cost_matrix[2][0])
        dut.cost_2_1.value = fp(cost_matrix[2][1])
        dut.cost_2_2.value = fp(cost_matrix[2][2])
        dut.cost_2_3.value = fp(cost_matrix[2][3])
        dut.cost_3_0.value = fp(cost_matrix[3][0])
        dut.cost_3_1.value = fp(cost_matrix[3][1])
        dut.cost_3_2.value = fp(cost_matrix[3][2])
        dut.cost_3_3.value = fp(cost_matrix[3][3])
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (max 16 cycles)
        for _ in range(20):
            if dut.done.value:
                break
            await RisingEdge(dut.clk)
        
        # Verify result
        result = dut.max_avg.value.integer
        actual = result / 256.0
        tolerance = 0.1  # Allow 0.1 Q8.8 tolerance
        
        if abs(actual - expected) < tolerance:
            passed += 1
            dut._log.info(f"PASS: Expected {expected:.2f}, got {actual:.2f}")
        else:
            dut._log.error(f"FAIL: Expected {expected:.2f}, got {actual:.2f}")
        
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{total} tests passed")
    assert passed == total