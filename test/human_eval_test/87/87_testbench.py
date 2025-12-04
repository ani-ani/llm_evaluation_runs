import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_find_coordinates(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    async def reset():
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        await Timer(1, units="ns")
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

    await reset()

    test_cases = [
        # Test case 1
        {
            "data": [[1,2,3,4,5,6], [1,2,3,4,1,6], [1,2,3,4,5,1]],
            "lens": [6,6,6,0,0,0,0,0],
            "target": 1,
            "expected": [(0,0), (1,4), (1,0), (2,5), (2,0)]
        },
        # Test case 2
        {
            "data": [[1,2,3,4,5,6]] * 6,
            "lens": [6,6,6,6,6,6,0,0],
            "target": 2,
            "expected": [(i,1) for i in range(6)]
        },
        # Test case 3
        {
            "data": [[], [1], [1,2,3]],
            "lens": [0,1,3,0,0,0,0,0],
            "target": 3,
            "expected": [(2,2)]
        }
    ]

    passed = 0
    for case in test_cases:
        # Fill data inputs
        for i in range(8):
            row_data = case["data"][i] if i < len(case["data"]) else []
            row_len = case["lens"][i]
            val = 0
            for j in range(8):
                if j < len(row_data):
                    val |= row_data[j] << (8*j)
                else:
                    val |= 0 << (8*j)
            getattr(dut, f"data_row{i}").value = val

        # Set inputs
        dut.target.value = case["target"]
        for i in range(8):
            dut.row_len.value = (dut.row_len.value & ~(0x7 << (3*i))) | (case["lens"][i] << (3*i))

        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion (max 70 cycles)
        for _ in range(70):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break

        # Check outputs
        count = dut.count.value
        expected = case["expected"]
        if count != len(expected):
            dut._log.error(f"Count mismatch: got {count}, expected {len(expected)}")
            continue

        correct = True
        for i in range(count):
            coord_val = dut.coordinates.value >> (6*i) & 0x3F
            row = (coord_val >> 3) & 0x7
            col = coord_val & 0x7
            if (row, col) != expected[i]:
                correct = False
                dut._log.error(f"Match {i}: expected {expected[i]}, got ({row}, {col})")

        if correct:
            passed += 1
            dut._log.info(f"PASS: Test case {test_cases.index(case)+1}")
        else:
            dut._log.error(f"FAIL: Test case {test_cases.index(case)+1}")

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)