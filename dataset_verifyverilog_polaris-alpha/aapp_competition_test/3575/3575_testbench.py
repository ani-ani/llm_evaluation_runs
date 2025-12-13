import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
import numpy as np

def graph_to_adj(edges, n):
    adj = 0
    for u,v in edges:
        adj |= (1 << (u*4 + v)) | (1 << (v*4 + u))
    return adj

def float_to_q16_16(val):
    if val == "never meet": return 0xFFFFFFFF
    return int(val * 65536) & 0xFFFFFFFF

@cocotb.test()
async def test_meet(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Test cases (scaled to max 4 stations)
    test_data = [
        (3, [(0,1), (1,2)], 0, 2, 1.0), # Sample 1
        (4, [(0,1), (2,3)], 0, 3, "never meet"), # Sample 2
        (2, [(0,1)], 0, 1, 0.0], # Additional: same station initially
        (4, [(0,1),(1,2),(2,3),(3,0)], 0, 2, 8.0) # Circular graph case
    ]

    passed = 0
    for n, edges, alice, bob, expected in test_data:
        # Convert to adj matrix format
        adj = graph_to_adj(edges, n)
        qval = float_to_q16_16(expected)

        # Apply reset
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        dut.start.value = 0
        await RisingEdge(dut.clk)

        # Load inputs
        dut.adjacency.value = adj
        dut.alice_start.value = alice
        dut.bob_start.value = bob
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion
        await ClockCycles(dut.clk, 20)
        if not dut.done.value:
            dut._log.error("Test timed out")
            continue

        # Check result
        if dut.expected_time.value == qval:
            passed += 1
        else:
            actual = dut.expected_time.value.integer
            actual_val = actual/65536.0 if actual != 0xFFFFFFFF else "never meet"
            dut._log.error(f"Failed: n={n}, A={alice}, B={bob}: expected {expected}, got {actual_val}")

    dut._log.info(f"{passed}/{len(test_data)} tests passed")
    assert passed == len(test_data)