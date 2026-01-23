import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_iscube(dut):
    """Test the iscube module for perfect cube detection"""
    
    # Create a clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.a.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (input_value, expected_result)
    test_cases = [
        (1, True),      # 1^3 = 1
        (2, False),     # Not a cube
        (-1, True),     # (-1)^3 = -1
        (64, True),     # 4^3 = 64
        (0, True),      # 0^3 = 0
        (180, False),   # Not a cube
        (1000, False),  # 10^3 = 1000, but out of range (max 127 for 8-bit)
        (125, True),    # 5^3 = 125
        (-125, True),   # (-5)^3 = -125
        (27, True),     # 3^3 = 27
        (-8, True),     # (-2)^3 = -8
    ]
    
    passed = 0
    total = len(test_cases)
    
    for val, expected in test_cases:
        # Check if value fits in 8-bit signed
        if val < -128 or val > 127:
            print(f"Skipping {val} (out of range)")
            total -= 1
            continue
            
        # Start computation
        dut.a.value = val
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal
        timeout = 0
        while not dut.done.value and timeout < 100:
            await RisingEdge(dut.clk)
            timeout += 1
        
        # Check result
        if timeout >= 100:
            print(f"Test FAILED for {val}: Timeout")
            continue
            
        actual = bool(dut.result.value)
        
        if actual == expected:
            passed += 1
            print(f"Test PASSED: iscube({val}) = {actual}")
        else:
            print(f"Test FAILED: iscube({val}) = {actual}, expected {expected}")
            
        # Small delay between tests
        await Timer(50, units='ns')
        
    print(f"
{passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"