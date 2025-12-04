import cocotb
from cocotb.triggers import RisingEdge, Timer, ClockCycles
from cocotb.clock import Clock
import itertools

@cocotb.test()
async def test_wheel_rotator(dut):
    # Setup clock and reset
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await Timer(5, units="ns")

    # Test cases (adapted to max 8 cols)
    test_cases = [
        (
            ["ABC", "ABC", "ABC"],   # Input strings
            2                           # Expected min rotations
        ),
        (
            ["ABBBAAAA", "BBBCCCBB", "CCCCAAAC"],
            3
        ),
        (
            ["AABB", "BBCC", "ACAC"],
            15                         # -1 case (0xF)
        ),
        (
            ["AA", "BB", "CC"],
            0                           # Already valid
        )
    ]

    passed = 0
    total = len(test_cases)

    for i, (wheels, expected) in enumerate(test_cases):
        # Reset module
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

        # Load input data (max 8 chars per wheel)
        str_len = len(wheels[0])
        dut.str_len.value = str_len
        for wheel_idx in range(3):
            char_str = wheels[wheel_idx]
            for col, char in enumerate(char_str):
                val = 0 if char == "A" else 1 if char == "B" else 2 if char == "C" else 3
                if wheel_idx == 0:
                    dut.wheel0[col].value = val
                elif wheel_idx == 1:
                    dut.wheel1[col].value = val
                else:
                    dut.wheel2[col].value = val

        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await RisingEdge(dut.clk)

        # Wait until done
        for _ in range(1000):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        else:
            assert False, "Timeout waiting for done"

        # Check results
        actual = dut.result.value.integer
        if actual == expected:
            passed += 1
        else:
            dut._log.error(f"Test case {i} failed: Expected {expected}, got {actual}")

    dut._log.info(f"{passed}/{total} tests passed")
