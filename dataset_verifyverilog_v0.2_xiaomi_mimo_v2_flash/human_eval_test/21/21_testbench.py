import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure

# Helper function to convert float to Q16.16 fixed-point
def float_to_q16_16(value):
    return int(value * 65536) & 0xFFFF

# Helper function to convert Q16.16 to float
def q16_16_to_float(value):
    if value & 0x8000:  # Negative number
        return (value - 0x10000) / 65536.0
    return value / 65536.0

@cocotb.test()
async def test_rescale_to_unit(dut):
    """Test rescale_to_unit module with various test cases"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.data_in.value = 0
    dut.data_valid.value = 0
    dut.data_last.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        ([2.0, 49.9], [0.0, 1.0]),
        ([100.0, 49.9], [1.0, 0.0]),
        ([1.0, 2.0, 3.0, 4.0, 5.0], [0.0, 0.25, 0.5, 0.75, 1.0]),
        ([2.0, 1.0, 5.0, 3.0, 4.0], [0.25, 0.0, 1.0, 0.5, 0.75]),
        ([12.0, 11.0, 15.0, 13.0, 14.0], [0.25, 0.0, 1.0, 0.5, 0.75])
    ]
    
    passed = 0
    total = len(test_cases)
    
    for test_num, (input_vals, expected_vals) in enumerate(test_cases):
        dut._log.info(f"Test {test_num + 1}: {input_vals} -> {expected_vals}")
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Feed input values
        for i, val in enumerate(input_vals):
            dut.data_in.value = float_to_q16_16(val)
            dut.data_valid.value = 1
            dut.data_last.value = 1 if i == len(input_vals) - 1 else 0
            await RisingEdge(dut.clk)
        
        dut.data_valid.value = 0
        dut.data_last.value = 0
        
        # Wait for computation to complete
        timeout = 0
        while not dut.done.value and timeout < 100:
            await RisingEdge(dut.clk)
            timeout += 1
        
        if timeout >= 100:
            raise TestFailure(f"Test {test_num + 1}: Timeout waiting for done signal")
        
        # Collect results
        results = []
        for i in range(len(input_vals)):
            # Wait for result_valid
            timeout = 0
            while not dut.result_valid.value and timeout < 10:
                await RisingEdge(dut.clk)
                timeout += 1
            
            if not dut.result_valid.value:
                raise TestFailure(f"Test {test_num + 1}: Result {i} not valid")
            
            result_val = q16_16_to_float(int(dut.result.value))
            results.append(result_val)
            await RisingEdge(dut.clk)
        
        # Check results
        try:
            for i, (actual, expected) in enumerate(zip(results, expected_vals)):
                diff = abs(actual - expected)
                if diff > 0.01:  # Allow small error for fixed-point
                    raise TestFailure(
                        f"Test {test_num + 1}, element {i}: Expected {expected:.4f}, got {actual:.4f}"
                    )
            dut._log.info(f"Test {test_num + 1} passed: {results}")
            passed += 1
        except TestFailure as e:
            dut._log.error(str(e))
        
        # Reset for next test
        dut.start.value = 0
        await RisingEdge(dut.clk)
    
    dut._log.info(f"
=== Summary: {passed}/{total} tests passed ===")
    if passed < total:
        raise TestFailure(f"Only {passed} out of {total} tests passed")
