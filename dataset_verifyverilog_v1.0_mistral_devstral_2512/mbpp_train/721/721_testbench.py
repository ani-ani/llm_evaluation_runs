import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# MANDATORY HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_grid_path_solver(dut):
    """Test the grid path solver module."""
    
    # Setup Clock (10ns period)
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset Sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.write.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Define Test Cases: (N, Matrix, Expected Average)
    test_cases = [
        (3, [[1, 2, 3], [6, 5, 4], [7, 3, 9]], 5.2),
        (3, [[2, 3, 4], [7, 6, 5], [8, 4, 10]], 6.2),
        (3, [[3, 4, 5], [8, 7, 6], [9, 5, 11]], 7.2),
        (3, [[1, 2, 3], [4, 5, 6], [7, 8, 9]], 5.8),
    ]
    
    passed = 0
    failed = 0
    
    for case_idx, (N, matrix, expected_avg) in enumerate(test_cases):
        dut._log.info(f"Test Case {case_idx + 1}: N={N}, Expected Avg={expected_avg}")
        
        try:
            # 1. Load Matrix into DUT
            # Address mapping: addr = row * 8 + col
            for r in range(N):
                for c in range(N):
                    dut.din.value = matrix[r][c]
                    dut.addr.value = (r * 8) + c
                    dut.write.value = 1
                    await RisingEdge(dut.clk)
                    dut.write.value = 0
            
            # 2. Set N and Start Computation
            dut.N.value = N
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # 3. Wait for Valid signal
            max_cycles = 200
            found_valid = False
            for _ in range(max_cycles):
                await RisingEdge(dut.clk)
                if is_value_defined(dut.valid.value) and int(dut.valid.value) == 1:
                    found_valid = True
                    break
            
            if not found_valid:
                raise TestFailure(f"Valid signal not asserted after {max_cycles} cycles")
            
            # 4. Read Results
            if not is_value_defined(dut.max_sum.value) or not is_value_defined(dut.path_len.value):
                raise TestFailure("Output signals are undefined (X/Z)")
            
            max_sum = int(dut.max_sum.value)
            path_len = int(dut.path_len.value)
            
            # 5. Verify Results
            # Calculate average from hardware outputs
            if path_len == 0:
                raise TestFailure("Path length is zero")
            
            calculated_avg = max_sum / path_len
            
            # Floating point comparison with tolerance
            if abs(calculated_avg - expected_avg) > 1e-4:
                raise TestFailure(f"Mismatch: Expected {expected_avg}, Got {calculated_avg} (Sum={max_sum}, Len={path_len})")
            
            dut._log.info(f"  PASS: Sum={max_sum}, Len={path_len}, Avg={calculated_avg:.4f}")
            passed += 1
            
        except TestFailure as e:
            dut._log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    dut._log.info(f"{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
