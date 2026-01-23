import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_simple_power(dut):
    """Test simple_power module with various test cases"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.x.value = 0
    dut.n.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases scaled for 8-bit inputs
    test_cases = [
        # (x, n, expected_result, description)
        (16, 2, 1, "16 is 2^4"),
        (143, 16, 0, "143 is not a power of 16"),
        (4, 2, 1, "4 is 2^2"),
        (9, 3, 1, "9 is 3^2"),
        (16, 4, 1, "16 is 4^2"),
        (24, 2, 0, "24 is not a power of 2"),
        (128, 4, 0, "128 is not a power of 4"),
        (12, 6, 0, "12 is not a power of 6"),
        (1, 1, 1, "1 is 1^0"),
        (1, 12, 1, "1 is 12^0"),
        (1, 2, 1, "1 is 2^0"),
        (2, 2, 1, "2 is 2^1"),
        (8, 2, 1, "8 is 2^3"),
        (3, 2, 0, "3 is not a power of 2"),
        (3, 1, 0, "3 is not a power of 1 (only 1^k = 1)"),
        (5, 3, 0, "5 is not a power of 3"),
        (27, 3, 1, "27 is 3^3"),
        (64, 2, 1, "64 is 2^6"),
        (65, 2, 0, "65 is not a power of 2"),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for x_val, n_val, expected, desc in test_cases:
        # Set inputs
        dut.x.value = x_val
        dut.n.value = n_val
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (max 32 cycles)
        timeout = 50
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        else:
            raise TestFailure(f"Timeout for x={x_val}, n={n_val}")
        
        # Check result
        actual = int(dut.result.value)
        if actual == expected:
            passed += 1
            print(f"PASS: {desc} (x={x_val}, n={n_val}) -> result={actual}")
        else:
            raise TestFailure(f"FAIL: {desc} (x={x_val}, n={n_val}) expected={expected}, got={actual}")
        
        # Reset for next test
        dut.rst_n.value = 0
        await Timer(20, units='ns')
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    print(f"
=== SUMMARY: {passed}/{total} tests passed ===")
    assert passed == total, f"Some tests failed: {passed}/{total} passed"
