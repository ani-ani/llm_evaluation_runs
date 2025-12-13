import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_list_histogram(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test case 1: [[1,3,0,0], [5,7,0,0], [1,3,0,0], [9,11,0,0]]
    test1 = [
        [1,3,0,0],
        [5,7,0,0],
        [1,3,0,0],
        [9,11,0,0]
    ]
    expected1 = {
        (1,3,0,0): 2,
        (5,7,0,0): 1,
        (9,11,0,0): 1
    }

    # Apply test vectors
    for i in range(4):
        dut.sublists[i].value = (test1[i][0] << 24) | (test1[i][1] << 16) | 
                                  (test1[i][2] << 8) | test1[i][3]
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Wait 5 cycles (4 processing + done)
    for _ in range(5):
        await RisingEdge(dut.clk)

    # Check results
    passed = 0
    slot_count = 0
    for i in range(4):
        if dut.counts[i].value != 0:
            slot_count += 1
            val = (
                (dut.unique_lists[i].value >> 24) & 0xff,
                (dut.unique_lists[i].value >> 16) & 0xff,
                (dut.unique_lists[i].value >> 8) & 0xff,
                dut.unique_lists[i].value & 0xff
            )
            cnt = dut.counts[i].value.integer
            expected_cnt = expected1.get(val, 0)
            if cnt == expected_cnt:
                passed += 1
                dut._log.info(f"PASS: Slot {i}: {val} count={cnt}")
            else:
                dut._log.error(f"FAIL: Slot {i}: {val} count={cnt}, expected {expected_cnt}")

    # Verify total expected matches
    total_expected = len(expected1)
    if slot_count == total_expected:
        passed += 1
        dut._log.info(f"PASS: Found {slot_count} unique lists")
    else:
        dut._log.error(f"FAIL: Found {slot_count} unique lists, expected {total_expected}")

    # Final results
    dut._log.info(f"{passed}/{total_expected + 1} tests passed")
