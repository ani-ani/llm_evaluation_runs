import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
import random

def solve_single(start_idx, cans):
    # Python reference implementation
    n = len(cans)
    visited = {start_idx}
    queue = [start_idx]
    while queue:
        curr = queue.pop(0)
        x_curr, r_curr = cans[curr]
        for i in range(n):
            if i not in visited:
                x_i, _ = cans[i]
                if abs(x_curr - x_i) <= r_curr:
                    visited.add(i)
                    queue.append(i)
    return len(visited)

@cocotb.test()
async def test_worm_cans(dut):
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 1: From problem description (scaled down to 3 cans)
    cans1 = [(4, 3), (-10, 9), (-2, 3)]
    # Sort by x
    cans1.sort(key=lambda t: t[0])
    
    dut.n.value = len(cans1)
    for i, (x, r) in enumerate(cans1):
        dut.x[i].value = x
        dut.r[i].value = r

    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Wait for done
    while not dut.done.value:
        await RisingEdge(dut.clk)

    # Check results
    passed = 0
    total = len(cans1)
    for i in range(total):
        expected = solve_single(i, cans1)
        actual = int(dut.result[i].value)
        dut._log.info(f"Can {i}: Expected {expected}, Got {actual}")
        if expected == actual:
            passed += 1

    # Test Case 2: Scaled example (N=5 to fit hardware limit)
    # Original had N=12, we reduce to 5
    cans2 = [(2, 2), (7, 7), (10, 1), (19, 3), (23, 12)]
    # Sort
    cans2.sort(key=lambda t: t[0])
    
    dut.n.value = len(cans2)
    for i, (x, r) in enumerate(cans2):
        dut.x[i].value = x
        dut.r[i].value = r

    await RisingEdge(dut.clk) # Synchronize inputs
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    while not dut.done.value:
        await RisingEdge(dut.clk)

    for i in range(len(cans2)):
        expected = solve_single(i, cans2)
        actual = int(dut.result[i].value)
        dut._log.info(f"Can {i}: Expected {expected}, Got {actual}")
        if expected == actual:
            passed += 1

    total += len(cans2)

    dut._log.info(f"{passed}/{total} tests passed")
    assert passed == total
}