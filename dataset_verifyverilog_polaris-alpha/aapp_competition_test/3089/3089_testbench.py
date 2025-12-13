import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import numpy as np

def to_q16(value):
    return int(value * 65536)

def float_from_q16(qval):
    return qval / 65536.0

@cocotb.test()
async def test_taxi(dut):
    # Generate clock (100 MHz)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test case 1: Unit square (Q16.16 format)
    square_verts_x = [to_q16(0.0), to_q16(0.0), to_q16(1.0), to_q16(1.0)]
    square_verts_y = [to_q16(0.0), to_q16(1.0), to_q16(1.0), to_q16(0.0)]

    # Load vertices (pad unused with zeros)
    for i in range(8):
        dut.vertices_x[i].value = square_verts_x[i] if i < 4 else 0
        dut.vertices_y[i].value = square_verts_y[i] if i < 4 else 0
    dut.num_vertices.value = 4
    await RisingEdge(dut.clk)

    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Wait for completion (timeout 20k cycles)
    for _ in range(20000):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    else:
        assert False, "Timeout waiting for done"

    # Check result (expected 2/3 ≈ 0.666667 in Q16.16)
    expected_val = to_q16(2/3)
    measured_val = dut.expected.value
    error = abs(float_from_q16(measured_val) - 0.666667)
    assert error < 0.02, f"Square test failed: {float_from_q16(measured_val):.6f} (error {error:.6f})"

    # Test case 2: Triangle (reuse hardware)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    triangle_verts_x = [to_q16(0.0), to_q16(1.0), to_q16(2.0)]
    triangle_verts_y = [to_q16(0.0), to_q16(1.0), to_q16(0.0)]
    for i in range(8):
        dut.vertices_x[i].value = triangle_verts_x[i] if i < 3 else 0
        dut.vertices_y[i].value = triangle_verts_y[i] if i < 3 else 0
    dut.num_vertices.value = 3
    await RisingEdge(dut.clk)

    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    for _ in range(20000):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    else:
        assert False, "Timeout waiting for done"

    expected_val_tri = to_q16(0.733333)
    measured_val_tri = dut.expected.value
    error_tri = abs(float_from_q16(measured_val_tri) - 0.733333)
    assert error_tri < 0.02, f"Triangle test failed: {float_from_q16(measured_val_tri):.6f}"
    dut._log.info("2/2 tests passed within tolerance")