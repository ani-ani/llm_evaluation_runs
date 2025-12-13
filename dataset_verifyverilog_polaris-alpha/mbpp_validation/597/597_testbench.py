import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_kth_element(dut):
    # Clock setup
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Test cases (array1, array2, k, expected_result, expected_error)
    test_cases = [
        # Original Test 1 (packed to 8 elements with padding)
        ([2,3,6,7,9,0,0,0], [1,4,8,10,0,0,0,0], 5, 6, False),
        # Test 2 scaled down
        ([100,112,256,349,770,0,0,0], [72,86,113,119,265,445,892,0], 7, 256, False),
        # Test 3 as-is
        ([3,4,7,8,10,0,0,0], [2,5,9,11,0,0,0,0], 6, 8, False),
        # Edge case: k=1
        ([5,0,0,0,0,0,0,0], [3,0,0,0,0,0,0,0], 1, 3, False),
        # Error case: k=9 when total length=5+2=7
        ([1,3,5,7,9,0,0,0], [2,4,0,0,0,0,0,0], 9, 0, True)
    ]

    passed = 0
    total = len(test_cases)

    for i, (a1, a2, k, expected, expect_error) in enumerate(test_cases):
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

        # Load arrays
        for idx in range(8):
            dut.arr1[idx].value = a1[idx]
            dut.arr2[idx].value = a2[idx]
        dut.arr1_len.value = sum(1 for x in a1 if x != 0)
        dut.arr2_len.value = sum(1 for x in a2 if x != 0)
        dut.k_in.value = k

        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for done or timeout (20 cycles max)
        timeout = 0
        while not dut.done.value and timeout < 20:
            await RisingEdge(dut.clk)
            timeout += 1

        # Verify results
        if dut.error.value != expect_error:
            dut._log.error(f"Test {i+1} error mismatched: {dut.error.value} vs {expect_error}")
        elif dut.error.value:
            dut._log.info(f"Test {i+1} error correctly triggered")
            passed += 1
        elif dut.kth_element.value == expected:
            dut._log.info(f"Test {i+1} PASS: Expected {expected}, got {dut.kth_element.value}")
            passed += 1
        else:
            dut._log.error(f"Test {i+1} FAIL: Expected {expected}, got {dut.kth_element.value}")

        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

    dut._log.info(f"Test summary: {passed}/{total} passed")
    assert passed == total