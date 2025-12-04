import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_convex_score(dut):
    clock = Clock(dut.clk, 10, units="ns")  # 100MHz clock
    cocotb.start_soon(clock.start())
    test_cases = [
        # Format: (x_list, y_list, expected)
        ([0,0,1,1], [0,1,0,1], 5),   # 4-point square
        ([0,1,2], [0,1,2], 0),       # 3 collinear points
        ([0,0,1], [0,1,0], 1)        # triangle
    ]
    passed = 0
    for x, y, expected in test_cases:
        # Reset and initialize
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        # Load points (pad with zeros for unused points)
        for i in range(8):
            dut.x[i].value = x[i] if i < len(x) else 0
            dut.y[i].value = y[i] if i < len(y) else 0
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        # Wait for completion (20 cycles)
        for _ in range(20):
            await RisingEdge(dut.clk)
        # Check result
        if int(dut.sum.value) == expected:
            passed += 1
        else:
            dut._log.error(f"Failed: Expected {expected}, got {dut.sum.value}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")