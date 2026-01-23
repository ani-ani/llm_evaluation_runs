import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_k_incremental(dut):
    # Create a clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.k_in.value = 0
    dut.n_in.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Helper async function to get string
    async def get_string(k, n):
        dut.k_in.value = k
        dut.n_in.value = n
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        result = []
        # Wait for completion or timeout
        for _ in range(20): # Should be enough cycles for k=2
            if dut.done.value == 1 and dut.error.value == 0:
                break
            if dut.char_valid.value == 1:
                # Read char
                char_val = dut.char_out.value.integer
                if 32 <= char_val < 128:
                    result.append(chr(char_val))
            await RisingEdge(dut.clk)
        
        if dut.error.value == 1:
            return "-1"
        return "".join(result)

    # Test Case 1: k=2, n=650 -> zyz
    # n=650 => index 649. 
    // 649 / 2 = 324. 
    // 324 pairs. 
    // Pair 324 is (y,z).
    // 649 % 2 = 1. Second string.
    // "zyz"
    res1 = await get_string(2, 650)
    if res1 != "zyz":
        raise TestFailure(f"Expected 'zyz', got '{res1}'")
    dut._log.info("Test 1 passed")

    # Test Case 2: k=2, n=651 -> -1 (error)
    res2 = await get_string(2, 651)
    if res2 != "-1":
        raise TestFailure(f"Expected '-1', got '{res2}'")
    dut._log.info("Test 2 passed")

    # Test Case 3: k=2, n=1 -> aba
    // n=1 => index 0. 
    // Pair 0: (a,b). 
    // String type 0: "aba".
    res3 = await get_string(2, 1)
    if res3 != "aba":
        raise TestFailure(f"Expected 'aba', got '{res3}'")
    dut._log.info("Test 3 passed")

    # Test Case 4: k=2, n=2 -> bab
    // n=2 => index 1.
    // Pair 0: (a,b).
    // String type 1: "bab".
    res4 = await get_string(2, 2)
    if res4 != "bab":
        raise TestFailure(f"Expected 'bab', got '{res4}'")
    dut._log.info("Test 4 passed")

    # Test Case 5: k=3 (should error in our simplified implementation)
    res5 = await get_string(5, 12345678901234)
    if res5 != "-1":
        raise TestFailure(f"Expected '-1' for k!=2, got '{res5}'")
    dut._log.info("Test 5 passed")

    # Summary
    dut._log.info("All tests passed!")
