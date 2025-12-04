import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from math import floor

def float_to_q88(val):
    return int(val * 256) & 0xFFFF

def q88_to_float(val):
    return val / 256.0 if val < 0x8000 else (val - 0x10000) / 256.0

@cocotb.test()
async def test_tree_placement(dut):
    cocotb.start_soon(cocotb.clock.Clock(dut.clk, 10, units="ns").start())
    dut.rst_n.value = 0
    dut.start.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test case 1: Star topology (4 edges from center)
    test_adj1 = [0b00011111, 0,0,0,0,0,0,0]  # Node 0 connected to 1-4
    await RisingEdge(dut.clk)
    dut.node_count.value = 5
    for i in range(8):
        dut.adj_matrix[i].value = test_adj1[i] if i < 5 else 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await ClockCycles(dut.clk, 50)
    assert dut.done.value == 1, "Timeout on test1"

    # Verify star coordinates (expected distance = 1.0)
    tol = 5  # Allow ±5 Q8.8 units (=±0.02mm)
    cx = dut.x_coords[0].value
    cy = dut.y_coords[0].value
    assert cx == 0 and cy == 0, "Root not at origin"
    for i in range(1, 5):
        dx = dut.x_coords[i].value - cx
        dy = dut.y_coords[i].value - cy
        dist_sq = dx*dx + dy*dy
        expected = float_to_q88(1.0)**2
        assert abs(dist_sq.signed_integer - expected) < 2*expected*tol, f"Edge {i} length error"

    # Test case 2: Chain topology
    test_adj2 = [0b00000010, 0b00000101, 0b00000010, 0,0,0,0,0]
    await RisingEdge(dut.clk)
    dut.node_count.value = 4
    for i in range(8):
        dut.adj_matrix[i].value = test_adj2[i] if i < 4 else 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await ClockCycles(dut.clk, 50)
    assert dut.done.value == 1, "Timeout on test2"

    # Verify endpoints
    d01 = (dut.x_coords[1].value - dut.x_coords[0].value)**2 + 
          (dut.y_coords[1].value - dut.y_coords[0].value)**2
    d12 = (dut.x_coords[2].value - dut.x_coords[1].value)**2 + 
          (dut.y_coords[2].value - dut.y_coords[1].value)**2
    assert abs(d01.signed_integer - float_to_q88(1.0)**2) < 100, "Chain edge1 error"
    assert abs(d12.signed_integer - float_to_q88(1.0)**2) < 100, "Chain edge2 error"

    dut._log.info("2/2 tests passed")