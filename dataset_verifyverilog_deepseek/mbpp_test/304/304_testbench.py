import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_rotation_finder(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    test_cases = [
        # Original Test 1
        {"arr": [1,2,3,4,5,0,0,0], "ranges": [[0,2],[0,3],[0,0],[0,0]], "rotations": 2, "index": 1, "expected": 3},
        # Original Test 2
        {"arr": [1,2,3,4,0,0,0,0], "ranges": [[0,1],[0,2],[0,0],[0,0]], "rotations": 1, "index": 2, "expected": 3},
        # Original Test 3
        {"arr": [1,2,3,4,5,6,0,0], "ranges": [[0,1],[0,2],[0,0],[0,0]], "rotations": 1, "index": 1, "expected": 1},
        # Additional test: No rotation
        {"arr": [9,8,7,6,5,4,3,2], "ranges": [[0,0],[0,0],[0,0],[0,0]], "rotations": 0, "index": 4, "expected": 5},
        # Edge test: Max rotations
        {"arr": [10,11,12,13,14,15,16,17], "ranges": [[1,3],[2,5],[0,6],[3,7]], "rotations": 3, "index": 3, "expected": 14}
    ]

    passed = 0
    total = len(test_cases)

    # Reset sequence
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    for tc in test_cases:
        # Load inputs
        for i in range(8):
            dut.arr[i].value = tc["arr"][i]
        for r in range(4):
            dut.ranges[r][0].value = tc["ranges"][r][0]
            dut.ranges[r][1].value = tc["ranges"][r][1]
        dut.rotations.value = tc["rotations"]
        dut.index.value = tc["index"]
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for computation
        cycles = tc["rotations"] + 1
        for _ in range(cycles):
            await RisingEdge(dut.clk)

        # Check result
        if dut.done.value == 1 and dut.result.value == tc["expected"]:
            passed += 1
            dut._log.info(f"PASS: Index={tc['index']} => {tc['expected']}")
        else:
            dut._log.error(f"FAIL: Got {dut.result.value}, Expected {tc['expected']} for {tc}")

        # Reset between tests
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

    dut._log.info(f"
SUMMARY: {passed}/{total} tests passed")
    assert passed == total