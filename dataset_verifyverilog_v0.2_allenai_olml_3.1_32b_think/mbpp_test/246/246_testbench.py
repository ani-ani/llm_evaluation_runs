import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
import math

@cocotb.test()
async def test_babylonian_sqrt(dut):
    # Test case format: (input_float, expected_float)
    test_cases = [
        (10.0, 3.162277660168379),
        (2.0, 1.414213562373095),
        (9.0, 3.0),
        (0.0, 0.0),
        (16.0, 4.0)
    ]
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.number.value = 0
    await Timer(20, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    passed = 0
    total = len(test_cases)
    
    for num_float, expected_float in test_cases:
        # Convert float to Q16.16 fixed-point
        num_fixed = int(num_float * 65536)
        expected_fixed = int(expected_float * 65536)
        
        dut.number.value = num_fixed
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal (allow ~30 cycles max)
        cycles = 0
        while dut.done.value == 0 and cycles < 50:
            await RisingEdge(dut.clk)
            cycles += 1
        
        if dut.done.value == 1:
            result = dut.sqrt_result.value.integer
            # Check with tolerance (approx +/- 0.005 in float = ~327 in Q16.16)
            if abs(result - expected_fixed) < 200:
                passed += 1
                dut._log.info(f"PASS: sqrt({num_float}) = {result/65536.:.6f} (expected {expected_float:.6f})")
            else:
                dut._log.error(f"FAIL: sqrt({num_float}) = {result/65536.:.6f} (expected {expected_float:.6f})")
        else:
            dut._log.error(f"FAIL: sqrt({num_float}) timed out")
        
        # Small delay between tests
        await Timer(100, units="ns")
    
    dut._log.info(f"Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"