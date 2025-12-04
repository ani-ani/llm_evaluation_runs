import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_secure_network(dut):
    # Clock generation
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await Timer(20, units="ns")

    # Test cases (adapted to 8 buildings max)
    test_cases = [
        # Test 1: Valid case (Sample Input 1)
        {
            "n": 4,
            "m": 6,
            "p": 1,
            "insecure": 0b0001,  # Building 1
            "edges": [
                (1,2,1), (1,3,1), (1,4,1),
                (2,3,2), (2,4,4), (3,4,3)
            ],
            "expected": 6
        },
        # Test 2: Impossible case (Sample Input 2)
        {
            "n": 4,
            "m": 3,
            "p": 2,
            "insecure": 0b0011,  # Buildings 1 & 2
            "edges": [
                (1,2,1), (2,3,7), (3,4,5)
            ],
            "expected": 0xFFFF
        },
        # Test 3: Single secure building
        {
            "n": 1,
            "m": 0,
            "p": 0,
            "insecure": 0,
            "edges": [],
            "expected": 0
        }
    ]

    passed = 0
    for i, tc in enumerate(test_cases):
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

        # Load inputs
        dut.num_buildings.value = tc["n"]
        dut.num_edges.value = tc["m"]
        dut.num_insecure.value = bin(tc["insecure"]).count("1")
        dut.insecure_mask.value = tc["insecure"]

        # Load edges (convert 1-based to 0-based)
        for j in range(16):
            src = dst = cost = 0
            if j < tc["m"]:
                src, dst, cost = tc["edges"][j]
                src -= 1  # convert to 0-based
                dst -= 1
            dut.edge_src[j].value = src
            dut.edge_dst[j].value = dst
            dut.edge_cost[j].value = cost

        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion (timeout at 300 cycles)
        timeout = 300
        while not dut.done.value and timeout > 0:
            await RisingEdge(dut.clk)
            timeout -= 1

        assert timeout > 0, "Simulation timed out"

        # Check result
        actual = dut.total_cost.value.integer
        expected = tc["expected"]
        if actual == expected:
            passed += 1
        else:
            dut._log.error(f"Test {i+1} failed: Expected {expected} (0x{expected:04X}), got {actual} (0x{actual:04X})")

        await RisingEdge(dut.clk)

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
