import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles
from fixed_point_models import Q16_16_to_float, float_to_Q16_16, Q8_8_to_float

@cocotb.test()
async def test_babylonian(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Fixed-point helpers (conceptual example)
    test_cases = [
        (10.0, 3.16227766),   # Test 1: sqrt(10)
        (2.0,  1.41421356),   # Test 2: sqrt(2)
        (9.0,  3.0),          # Test 3: sqrt(9)
        (0.0,  0.0),          # Edge: zero
        (256.0, 16.0),        # Edge: perfect square
        (65535.0, 256.0)      # Max Q16.16 input
    ]
    
    passed = 0
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    for num_float, expected_float in test_cases:
        # Convert to fixed-point
        num_q16 = int(num_float * (1 << 16))
        expected_q8 = int(expected_float * (1 << 8))
        tolerance = 5  # Allow ±5 in Q8.8 units (~±0.02 error)
        
        # Apply input
        dut.num.value = num_q16
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check result
        result_q8 = dut.result.value.integer
        error = abs(result_q8 - expected_q8)
        
        if error <= tolerance:
            passed += 1
            dut._log.info(f"PASS: sqrt({num_float}) = {Q8_8_to_float(result_q8):.6f} \
                          (expected {expected_float:.6f}, error {error} units)")
        else:
            dut._log.error(f"FAIL: sqrt({num_float}) = {Q8_8_to_float(result_q8):.6f} \
                           | Expected {expected_float:.6f} (Q8.8 {expected_q8}), got {result_q8} (error {error} units)")
        
        # Wait one cycle between tests
        await RisingEdge(dut.clk)
    
    # Results summary
    total = len(test_cases)
    dut._log.info(f"{passed}/{total} tests passed")
    assert passed == total

# Simple fixed-point conversion helpers
@cocotb.test(skip=True)
async def fixed_helpers():
    def float_to_Q16_16(f): return int(f * (1 << 16))
    def Q16_16_to_float(q): return q / (1 << 16)
    def float_to_Q8_8(f): return int(f * (1 << 8))
    def Q8_8_to_float(q): return q / (1 << 8)