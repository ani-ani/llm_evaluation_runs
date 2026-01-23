import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock

@cocotb.test()
async def test_catalan_number(dut):
    """Test catalan_number module with multiple test cases"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    # Test cases
    test_cases = [
        (0, 1),
        (1, 1),
        (2, 2),
        (3, 5),
        (4, 14),
        (5, 42),
        (6, 132),
        (7, 429),
        (8, 1430),
        (9, 4862),
        (10, 16796),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n, expected in test_cases:
        # Start computation
        dut.n.value = n
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 200
        for _ in range(timeout):
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)
        
        # Check result
        actual = int(dut.result.value)
        
        if actual == expected:
            passed += 1
            print(f"Test n={n}: PASS (result={actual})")
        else:
            print(f"Test n={n}: FAIL (expected={expected}, got={actual})")
        
        # Wait a bit before next test
        await Timer(20, units='ns')
    
    print(f"
{passed}/{total} tests passed")
    assert passed == total, f"Only {passed} out of {total} tests passed"
