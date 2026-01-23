import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

@cocotb.test()
async def test_hill_counter(dut):
    """Test hill counter with adapted 4-digit test cases"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Test cases adapted for 4-digit max
    test_cases = [
        (10, 10, "10 is hill"),
        (55, 55, "55 is hill"),
        (101, 0xFFFFFFFF, "101 is not hill"),
        (1234, 94708, "1234 is hill, count hills <=1234"),
        (1000, 715, "1000 is hill, count hills <=1000"),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n, expected, description in test_cases:
        # Start computation
        dut.n.value = n
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 0
        while not dut.done.value and timeout < 150:
            await RisingEdge(dut.clk)
            timeout += 1
        
        if timeout >= 150:
            raise TestFailure(f"Test '{description}' timed out")
        
        # Check result
        actual = int(dut.result.value)
        if actual == expected:
            passed += 1
            dut._log.info(f"PASS: {description}, n={n}, result={actual}")
        else:
            dut._log.error(f"FAIL: {description}, n={n}, expected={expected}, got={actual}")
    
    dut._log.info(f"
Test Summary: {passed}/{total} tests passed")
    if passed != total:
        raise TestFailure(f"Only {passed} out of {total} tests passed")