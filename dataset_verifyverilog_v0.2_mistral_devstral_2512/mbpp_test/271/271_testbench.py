import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

@cocotb.test()
async def test_even_power_sum(dut):
    """Test even_power_sum module with multiple test cases"""
    
    # Create clock (10ns period)
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
    
    # Test cases: (n, expected_result)
    # Expected values in Q16.16 format
    # even_Power_Sum(1) = 32 = 32 * 65536 = 2097152 (0x200000)
    # even_Power_Sum(2) = 1056 = 1056 * 65536 = 69226496 (0x4200000)
    # even_Power_Sum(3) = 8832 = 8832 * 65536 = 578822144 (0x22800000)
    
    test_cases = [
        (1, 2097152),      # 32 in Q16.16
        (2, 69226496),     # 1056 in Q16.16
        (3, 578822144),    # 8832 in Q16.16
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n_val, expected in test_cases:
        # Start computation
        dut.n.value = n_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (max 20 cycles for safety)
        timeout = 20
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        else:
            raise TestFailure(f"Test n={n_val}: Timeout waiting for done")
        
        # Check result
        actual = int(dut.result.value)
        if actual == expected:
            passed += 1
            print(f"Test n={n_val}: PASS (result={actual})")
        else:
            print(f"Test n={n_val}: FAIL (expected={expected}, actual={actual})")
            raise TestFailure(f"n={n_val}: Expected {expected}, got {actual}")
    
    print(f"
Summary: {passed}/{total} tests passed")
    if passed != total:
        raise TestFailure(f"Only {passed}/{total} tests passed")