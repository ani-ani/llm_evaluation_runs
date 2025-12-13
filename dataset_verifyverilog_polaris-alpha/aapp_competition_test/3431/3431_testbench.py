import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
from random import randint

# Helper to compute expected MST
def manhattan_mst_expected(n, points):
    edges = []
    for i in range(n):
        for j in range(i+1, n):
            dist = abs(points[i][0]-points[j][0]) + abs(points[i][1]-points[j][1])
            edges.append((dist, i, j))
    edges.sort()
    parent = list(range(n))
    ###########
    def find(u):
        if parent[u] != u:
            parent[u] = find(parent[u])
        return parent[u]
    ###########
    total = 0
    for dist, u, v in edges:
        pu, pv = find(u), find(v)
        if pu != pv:
            parent[pu] = pv
            total += dist
    return total

@cocotb.test()
async def test_mst(dut):
    """Test MST calculation for scaled test cases"""
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
    # Test cases (scaled to <=8 points)
    test_cases = [
        (4, [(0,0), (0,1), (1,0), (1,1)], 3),
        (5, [(0,0), (10,0), (10,0), (11,1), (12,2)], 14),
        (3, [(5,5), (5,10), (10,5)], 10)
    ]
    passed = 0
    for n, points_data, expected in test_cases:
        # Apply inputs
        dut.num_points.value = n
        for i in range(len(points_data)):
            dut.x[i].value = points_data[i][0]
            dut.y[i].value = points_data[i][1]
        for i in range(len(points_data), 8):
            dut.x[i].value = 0
            dut.y[i].value = 0
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        # Wait for completion
        timeout = 100
        while not dut.done.value and timeout > 0:
            await RisingEdge(dut.clk)
            timeout -= 1
        # Verify result
        if timeout == 0:
            dut._log.error("Timeout waiting for done")
        elif dut.mst_weight.value == expected:
            dut._log.info(f"Test passed for n={n}")
            passed += 1
        else:
            real_expected = manhattan_mst_expected(n, points_data)
            dut._log.error(f"Test failed: n={n} got={dut.mst_weight.value} expected={real_expected}")
        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    # Final report
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases), "Some tests failed"