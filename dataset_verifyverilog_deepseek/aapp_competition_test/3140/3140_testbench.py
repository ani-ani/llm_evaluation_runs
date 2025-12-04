import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_fish_counter(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Test cases (scaled to 4x4 grid)
    test_cases = [
        { # TC1: Original sample scaled
            "grid": [ [1,4,0,0], [3,2,0,0], [0,0,0,0], [0,0,0,0] ],
            "x0": 0, "y0": 0, "k": 1, "l": 10,
            "expected": 2
        },
        { # TC2: Original sample scaled
            "grid": [ [1,1,6,0], [1,2,2,0], [0,0,0,0], [0,0,0,0] ],
            "x0": 1, "y0": 1, "k": 5, "l": 6,
            "expected": 5
        },
        { # TC3: Edge case - max coverage
            "grid": [ [1,1,1,1], [1,1,1,1], [1,1,1,1], [1,1,1,1] ],
            "x0": 0, "y0": 0, "k": 16, "l": 16,
            "expected": 16
        }
    ]

    passed = 0
    dut._log.info(f"Running {len(test_cases)} tests")

    for tc in test_cases:
        # Reset sequence
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

        # Load grid inputs (pad to 4x4)
        for x in range(4):
            for y in range(4):
                if x < len(tc["grid"]) and y < len(tc["grid"][x]):
                    dut.t_grid[x * 4 + y].value = tc["grid"][x][y]
                else:
                    dut.t_grid[x * 4 + y].value = 0

        # Set control inputs
        dut.x0.value = tc["x0"]
        dut.y0.value = tc["y0"]
        dut.k_val.value = tc["k"]
        dut.l_val.value = tc["l"]
        await RisingEdge(dut.clk)

        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await RisingEdge(dut.clk)

        # Wait for completion
        for _ in range(32):
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)
        else:
            assert False, "Timeout waiting for done"

        # Verify result
        actual = dut.count.value.integer
        if actual == tc["expected"]:
            passed += 1
            dut._log.info(f"Test passed: expected={tc["expected"]}, actual={actual}")
        else:
            dut._log.error(f"Test failed: expected={tc["expected"]}, actual={actual}")

    # Final report
    dut._log.info(f"
SUMMARY: {passed}/{len(test_cases)} tests passed")