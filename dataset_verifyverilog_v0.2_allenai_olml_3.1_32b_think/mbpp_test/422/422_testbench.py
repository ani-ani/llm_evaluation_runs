import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

def float_to_q16_16(value):
    """Convert float to Q16.16 fixed-point representation"""
    return int(value * 65536)

def q16_16_to_float(value):
    """Convert Q16.16 fixed-point to float"""
    return value / 65536.0

@cocotb.test()
async def test_average_of_cubes(dut):
    """Test average of cubes module with various values of n"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        (1, 1.0),      # n=1, avg=1^3/1=1
        (2, 4.5),      # n=2, avg=(1+8)/2=4.5
        (3, 12.0),     # n=3, avg=(1+8+27)/3=12
        (4, 32.5),     # n=4, avg=(1+8+27+64)/4=25
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n_input, expected_avg in test_cases:
        # Start computation
        dut.n.value = n_input
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (with timeout)
        timeout = 20
        cycles = 0
        while not dut.done.value and cycles < timeout:
            await RisingEdge(dut.clk)
            cycles += 1
        
        if cycles >= timeout:
            raise TestFailure(f"Test failed for n={n_input}: Timeout waiting for done signal")
        
        # Read result
        result_raw = dut.result.value
        result_float = q16_16_to_float(int(result_raw))
        
        # Check result with tolerance for fixed-point precision
        tolerance = 1e-4
        if abs(result_float - expected_avg) < tolerance:
            print(f"Test n={n_input}: PASSED (got {result_float:.6f}, expected {expected_avg:.6f})")
            passed += 1
        else:
            print(f"Test n={n_input}: FAILED (got {result_float:.6f}, expected {expected_avg:.6f})")
            raise TestFailure(f"n={n_input}: Expected {expected_avg}, got {result_float}")
        
        await RisingEdge(dut.clk)
    
    print(f"
Summary: {passed}/{total} tests passed")
    
    if passed != total:
        raise TestFailure(f"Only {passed} out of {total} tests passed")