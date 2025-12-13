import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_spanning_tree(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Test cases (adapted to 8-node limit)
    test_cases = [
        # Original sample input (3 nodes)
        (3, 3, 2, [
            0b1_0000_001_010,  # B 1 2 (nodes 1&2 = indices 001 & 010)
            0b1_0000_010_011,  # B 2 3
            0b0_0000_011_001   # R 3 1
        ], 1),
        # Original test case 2 (2 nodes)
        (2, 1, 1, [
            0b0_0000_001_010   # R 1 2
        ], 0),
        # Additional edge case (impossible k)
        (4, 4, 3, [
            0b1_0000_001_010,  # B 1-2
            0b1_0000_010_011,  # B 2-3
            0b1_0000_011_100,  # B 3-4
            0b0_0000_100_001   # R 4-1
        ], 0)
    ]

    dut._log.info("Starting tests")
    passed = 0
    total = len(test_cases)

    for (n, m, k, edge_list, expected) in test_cases:
        # Reset sequence
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

        # Load inputs
        dut.n.value = n
        dut.m.value = m
        dut.k.value = k
        for i in range(16):
            if i < len(edge_list):
                dut.edges[i].value = edge_list[i]
            else:
                dut.edges[i].value = 0  # unused edges set to 0

        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait until done
        for _ in range(35):  # 32 cycles + margin
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break

        # Verify result
        if dut.result.value != expected:
            dut._log.error(f"Failed case: n={n}, m={m}, k={k}. Got {dut.result.value}, expected {expected}")
        else:
            passed += 1

    dut._log.info(f"TEST SUMMARY: {passed}/{total} tests passed")
    assert passed == total