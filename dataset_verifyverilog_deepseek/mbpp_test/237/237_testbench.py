import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_tuple_counter(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test data structure: 
    # (test_count, [input_tuples], [{expected_tuples}, expected_counts])
    test_cases = [
        (
            5,
            [[3,1], [1,3], [2,5], [5,2], [6,3]],
            {
                (1,3): 2,
                (2,5): 2,
                (3,6): 1
            }
        ),
        (
            5,
            [[4,2], [2,4], [3,6], [6,3], [7,4]],
            {
                (2,4): 2,
                (3,6): 2,
                (4,7): 1
            }
        ),
        (
            5,
            [[13,2], [11,23], [12,25], [25,12], [16,23]],
            {
                (2,13): 1,
                (11,23): 1,
                (12,25): 2,
                (16,23): 1
            }
        )
    ]

    passed = 0

    for count, input_data, expected in test_cases:
        # Load inputs
        for i in range(8):
            if i < len(input_data):
                dut.tuples[i][0].value = input_data[i][0]
                dut.tuples[i][1].value = input_data[i][1]
            else:
                dut.tuples[i][0].value = 0
                dut.tuples[i][1].value = 0

        dut.tuple_count.value = count

        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)

        # Check results
        match_count = 0
        valid = True

        # Verify all expected entries exist
        for tup, cnt in expected.items():
            found = False
            for i in range(dut.unique_count.value):
                stored = (int(dut.unique_tuples[i][0].value), int(dut.unique_tuples[i][1].value))
                if stored == tup:
                    if int(dut.counts[i].value) == cnt:
                        found = True
                        match_count += 1
                        break

            if not found:
                valid = False
                dut._log.error(f"Missing tuple {tup} with count {cnt}")

        # Check total unique count matches
        if dut.unique_count.value != len(expected):
            dut._log.error(f"Unique count mismatch: {dut.unique_count.value} vs {len(expected)}")
            valid = False

        if valid and match_count == len(expected):
            passed += 1
            dut._log.info(f"PASS Test: {input_data}")
        else:
            dut._log.error(f"FAIL Test: {input_data}")

    # Summary
    total = len(test_cases)
    dut._log.info(f"
--- SUMMARY ---
{passed}/{total} tests passed")
    assert passed == total, f"Failed {total-passed}/{total} tests"