import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import math

def to_fixed_point(value):
    """Convert decimal to Q16.16 fixed-point format"""
    return int(value * 65536)

def from_fixed_point(value):
    """Convert Q16.16 fixed-point to decimal"""
    return value / 65536.0

@cocotb.test()
async def test_project_optimizer(dut):
    """Test the project optimizer module with multiple test cases"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    dut.p.value = 0
    dut.q.value = 0
    for i in range(8):
        setattr(dut, f'a_i_{i}', 0)
        setattr(dut, f'b_i_{i}', 0)
    
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases adapted for fixed size (max 8 projects)
    test_cases = [
        # (n, p, q, [(a1, b1), (a2, b2), ...], expected_days)
        (3, 20, 20, [(6, 2), (1, 3), (2, 6)], 5.0),  # Original example
        (4, 1, 1, [(2, 3), (3, 2), (2, 3), (3, 2)], 0.4),  # Single project enough
        (3, 12, 12, [(5, 1), (2, 2), (1, 5)], 4.0),  # Three points
        (1, 4, 6, [(2, 3)], 2.0),  # Single project
        (2, 10, 3, [(2, 4), (5, 2)], 2.0),  # Two projects
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (n_val, p_val, q_val, projects, expected) in enumerate(test_cases):
        print(f"
Test case {i+1}: n={n_val}, p={p_val}, q={q_val}")
        
        # Load inputs
        dut.n.value = n_val
        dut.p.value = p_val
        dut.q.value = q_val
        
        # Load projects (pad to 8)
        for j in range(8):
            if j < len(projects):
                setattr(dut, f'a_i_{j}', projects[j][0])
                setattr(dut, f'b_i_{j}', projects[j][1])
            else:
                setattr(dut, f'a_i_{j}', 0)
                setattr(dut, f'b_i_{j}', 0)
        
        # Start computation
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (with timeout)
        timeout = 1000
        for _ in range(timeout):
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)
        else:
            raise TestFailure(f"Test {i+1}: Timeout waiting for done signal")
        
        # Read result
        result_fp = int(dut.result.value)
        result = from_fixed_point(result_fp)
        
        # Check with tolerance
        abs_error = abs(result - expected)
        rel_error = abs_error / max(1.0, expected)
        
        print(f"  Expected: {expected:.16f}")
        print(f"  Got:      {result:.16f}")
        print(f"  Error:    {rel_error:.2e}")
        
        if rel_error <= 1e-6 or abs_error <= 1e-6:
            passed += 1
            print(f"  PASSED")
        else:
            print(f"  FAILED")
            raise TestFailure(f"Test {i+1}: Error {rel_error:.2e} exceeds tolerance")
    
    print(f"
=== Summary: {passed}/{total} tests passed ===")
    
    if passed == total:
        print("All tests completed successfully!")
