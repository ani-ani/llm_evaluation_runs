import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_rounded_avg(dut):
    """Test the rounded_avg module"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    dut.m.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases scaled to 8-bit
    test_cases = [
        # (n, m, expected_result, expected_error, description)
        (1, 5, 3, 0, "1 to 5: avg=3, binary=00000011"),
        (7, 13, 10, 0, "7 to 13: avg=10, binary=00001010"),
        (7, 5, 0, 1, "7 to 5: n>m, error expected"),
        (5, 5, 5, 0, "5 to 5: avg=5, binary=00000101"),
        (1, 7, 4, 0, "1 to 7: avg=4, binary=00000100"),
        (0, 3, 2, 0, "0 to 3: avg=2, binary=00000010"),
        (100, 104, 102, 0, "100 to 104: avg=102, binary=01100110"),
        (250, 255, 252, 0, "250 to 255: avg=252, binary=11111100"),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n, m, expected_result, expected_error, desc in test_cases:
        # Start computation
        dut.n.value = n
        dut.m.value = m
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (max 15 cycles to be safe)
        cycles = 0
        while not dut.done.value and cycles < 15:
            await RisingEdge(dut.clk)
            cycles += 1
        
        if cycles >= 15:
            raise TestFailure(f"Test '{desc}' - Module did not complete within 15 cycles")
        
        # Check results
        if expected_error:
            if dut.error.value != 1:
                raise TestFailure(f"Test '{desc}' - Expected error=1, got {dut.error.value}")
            passed += 1
        else:
            if dut.error.value != 0:
                raise TestFailure(f"Test '{desc}' - Expected error=0, got {dut.error.value}")
            if dut.result.value != expected_result:
                raise TestFailure(f"Test '{desc}' - Expected result={expected_result} ({expected_result:08b}), got {dut.result.value} ({int(dut.result.value):08b})")
            passed += 1
        
        await RisingEdge(dut.clk)
    
    print(f"
=== Test Summary ===")
    print(f"{passed}/{total} tests passed")
    if passed == total:
        print("All tests PASSED!")
    else:
        print(f"FAILED: {total - passed} tests failed")