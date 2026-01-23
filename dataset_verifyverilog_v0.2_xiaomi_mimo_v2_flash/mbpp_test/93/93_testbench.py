import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

@cocotb.test()
async def test_power_calculator(dut):
    """Test power calculator with various inputs"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.a.value = 0
    dut.b.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Test cases
    test_cases = [
        # (a, b, expected, description)
        (3, 4, 81, "3^4 = 81"),
        (2, 3, 8, "2^3 = 8"),
        (5, 5, 3125, "5^5 = 3125"),
        (7, 0, 1, "7^0 = 1 (exponent zero)"),
        (0, 5, 0, "0^5 = 0 (base zero)"),
        (0, 0, 1, "0^0 = 1 (convention)"),
        (10, 1, 10, "10^1 = 10 (exponent one)"),
        (2, 15, 32768, "2^15 = 32768 (max power)"),
        (4, 6, 4096, "4^6 = 4096"),
        (6, 4, 1296, "6^4 = 1296")
    ]
    
    passed = 0
    total = len(test_cases)
    
    for a, b, expected, description in test_cases:
        # Set inputs
        dut.a.value = a
        dut.b.value = b
        dut.start.value = 1
        
        # Wait for start to be sampled
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal (max 18 cycles + some margin)
        timeout = 25
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        else:
            raise TestFailure(f"Timeout for {description}: done never asserted")
        
        # Read result
        result = int(dut.result.value)
        
        # Check
        if result == expected:
            print(f"PASS: {description} = {result}")
            passed += 1
        else:
            print(f"FAIL: {description} = {result} (expected {expected})")
            raise TestFailure(f"{description} got {result} expected {expected}")
        
        # Wait for done to go low before next test
        await RisingEdge(dut.clk)
    
    print(f"
Test Summary: {passed}/{total} tests passed")
    if passed == total:
        print("All tests PASSED!")
