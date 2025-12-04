import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_doll_counter(dut):
    # Test cases: (p_value, prices_array, expected_count)
    test_cases = [
        (3, [1,2,3,0,0,0,0,0], 1),  # Original sample 1 (padded)
        (2, [1,3,2,0,0,0,0,0], 5),  # Original sample 2 (padded)
        (3, [1,3,2,0,0,0,0,0], 1),  # Original sample 3 (padded)
        (0, [5,5,5,5,5,5,5,5], 36), # All subsequences valid
        (100, [99]*8, 0),           # No subsequences valid
        (10, [15,5,20,10,0,0,0,0], 10) # Manual calculation case
    ]

    passed = 0
    for p_val, prices, expected in test_cases:
        dut.p_value.value = p_val
        for i in range(8):
            dut.prices[i].value = prices[i]
        await Timer(1, units='ns')
        result = dut.count.value.integer
        if result == expected:
            passed += 1
        else:
            dut._log.error("Test failed: P=%d Prices=%s => %d (expected %d)" % 
                          (p_val, str(prices), result, expected))
    dut._log.info("%d/%d tests passed" % (passed, len(test_cases)))