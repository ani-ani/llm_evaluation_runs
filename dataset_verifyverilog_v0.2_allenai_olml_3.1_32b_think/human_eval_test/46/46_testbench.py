import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_fib4(dut):
    # Create a clock with 10ns period
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    await Timer(25, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (n, expected_result)
    test_cases = [
        (5, 4),
        (8, 28),
        (10, 104),
        (12, 386),
        (0, 0),
        (1, 0),
        (2, 2),
        (3, 0),
        (4, 2),  # 0+0+2+0 = 2
        (6, 8),
        (7, 14),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n, expected in test_cases:
        # Set input
        dut.n.value = n
        await RisingEdge(dut.clk)
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 20  # max cycles to wait
        for _ in range(timeout):
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)
        else:
            raise TestFailure(f"Timeout waiting for done for n={n}")
        
        # Check result
        actual = int(dut.result.value)
        if actual == expected:
            passed += 1
            print(f"n={n}: PASS - got {actual}")
        else:
            print(f"n={n}: FAIL - expected {expected}, got {actual}")
            raise TestFailure(f"n={n}: expected {expected}, got {actual}")
        
        # Small delay before next test
        await Timer(10, units='ns')
    
    print(f"
Summary: {passed}/{total} tests passed")
    if passed == total:
        print("All tests passed!")
