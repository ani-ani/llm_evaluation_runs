import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_max_aggregate(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Student ID mapping
    JUAN = 0
    SABAH = 1
    PETER = 2

    # Test cases (student_id, marks, last_entry)
    test_vectors = [
        # Test 1
        [(JUAN, 90, 0), (SABAH, 88, 0), (PETER, 7, 0), (JUAN, 122, 0), (SABAH, 84, 1)],
        # Test 2
        [(JUAN, 50, 0), (SABAH, 48, 0), (PETER, 37, 0), (JUAN, 22, 0), (SABAH, 14, 1)],
        # Test 3
        [(JUAN, 10, 0), (SABAH, 20, 0), (PETER, 30, 0), (JUAN, 40, 0), (SABAH, 50, 1)]
    ]

    expected = [
        (JUAN, 212),   # Test 1
        (JUAN, 72),    # Test 2
        (SABAH, 70)    # Test 3
    ]

    passed = 0

    for i, entries in enumerate(test_vectors):
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

        # Apply start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Process entries
        for idx, (sid, marks, last) in enumerate(entries):
            dut.student_id.value = sid
            dut.marks.value = marks
            dut.last_entry.value = last
            await RisingEdge(dut.clk)

        # Wait for completion (2 extra cycles)
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)

        # Check results
        expected_id, expected_score = expected[i]
        if dut.done.value == 1 and dut.max_id.value == expected_id and dut.max_score.value == expected_score:
            passed += 1
            dut._log.info(f"PASSED Test {i+1}")
        else:
            dut._log.error(f"FAIL Test {i+1}: Got ({dut.max_id.value}, {dut.max_score.value}), 
                Expected ({expected_id}, {expected_score})")

    dut._log.info(f"{passed}/{len(test_vectors)} tests passed")