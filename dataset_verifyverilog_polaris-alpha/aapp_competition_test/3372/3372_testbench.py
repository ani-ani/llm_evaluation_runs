import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer

@cocotb.test()
async def test_flight_path(dut):
    # Clock generation
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Test cases (adapted to 4-airport examples)
    test_cases = [
        (4, 0, 1, 0b0000, [
            0b00000100,  # Airport 0: N list [2]
            0b00000100,  # Airport 1: C list [2] (excluded)
            0b00001000,  # Airport 2: N list [3]
            0b00000010   # Airport 3: C list [1] (excluded)
        ], "impossible"),
        (4, 0, 1, 0b0000, [
            0b00000100,  # Airport 0: N list [2]
            0b00000100,  # Airport 1: C list [2] (excluded)
            0b00001000,  # Airport 2: N list [3]
            0b00000001   # Airport 3: C list [0] (excluded)
        ], 3)
    ]

    passed = 0
    for i, (N_val, s_val, t_val, types_val, lists_val, expected) in enumerate(test_cases):
        # Reset system
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

        # Load inputs
        dut.N.value = N_val - 1  # N=4 uses 3-bit rep
        dut.s.value = s_val
        dut.t.value = t_val
        dut.adj_types.value = types_val
        for j in range(8):
            if j < len(lists_val):
                dut.adj_lists[j].value = lists_val[j]
            else:
                dut.adj_lists[j].value = 0

        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion (timeout after 40 cycles)
        timeout = 40
        while not dut.done.value and timeout > 0:
            await RisingEdge(dut.clk)
            timeout -= 1

        assert timeout > 0, "Test timed out"

        # Check outputs
        if isinstance(expected, int):
            assert dut.impossible.value == 0, f"Test {i} incorrectly marked impossible"
            assert dut.hops.value == expected, f"Test {i} got {dut.hops.value} hops, expected {expected}"
        else:
            assert dut.impossible.value == 1, f"Test {i} should be impossible"
            passed += 1
        await RisingEdge(dut.clk)

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
