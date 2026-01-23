import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
import random

@cocotb.test()
async def test_inversion_counter(dut):
    # Test cases: (N, C, expected_output)
    # Expected values pre-computed modulo 1000000007
    test_cases = [
        (10, 1, 9),      # 10 elements, 1 inversion
        (4, 3, 6),       # 4 elements, 3 inversions
        (9, 13, 17957),  # 9 elements, 13 inversions
        (1, 0, 1),       # Edge case: single element, 0 inversions
        (5, 0, 1),       # Sorted array has 0 inversions
        (3, 2, 2),       # For N=3, C=2: permutations 321, 312 have 2 inversions
        (8, 10, 110932)  # Additional test
    ]

    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.N.value = 0
    dut.C.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    passed = 0
    total = len(test_cases)

    for N, C, expected in test_cases:
        print(f"Testing N={N}, C={C}, expected={expected}")
        
        # Set inputs
        dut.N.value = N
        dut.C.value = C
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for done
        timeout = 0
        while not dut.done.value and timeout < 20000:
            await RisingEdge(dut.clk)
            timeout += 1

        if timeout >= 20000:
            print(f"  FAILED: Timeout for N={N}, C={C}")
            continue

        # Check result
        result = int(dut.result.value)
        if result == expected:
            print(f"  PASSED: result={result}")
            passed += 1
        else:
            print(f"  FAILED: got {result}, expected {expected}")

    print(f"
Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"