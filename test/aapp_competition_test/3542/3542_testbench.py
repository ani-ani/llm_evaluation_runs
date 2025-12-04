import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
@cocotb.test()
async def test_wire_routing(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    test_cases = [
        (6, 3, (2,3), (4,0), (0,2), (6,1), True, 0),  # IMPOSSIBLE
        (6, 6, (2,1), (5,4), (4,0), (4,5), False, 15),
        (3, 3, (0,0), (3,3), (0,3), (3,0), False, 12),  # Cross solution
        (2, 2, (0,0), (2,2), (0,2), (2,0), True, 0)     # Small impossible
    ]
    passed = 0
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    for n, m, a1, a2, b1, b2, impos, length in test_cases:
        # Pack coordinates: {x[2:0], y[2:0]}
        dut.n.value = n
        dut.m.value = m
        dut.a1.value = (a1[0] << 3) | a1[1]
        dut.a2.value = (a2[0] << 3) | a2[1]
        dut.b1.value = (b1[0] << 3) | b1[1]
        dut.b2.value = (b2[0] << 3) | b2[1]
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        # Wait for completion (max 300 cycles)
        for _ in range(300):
            await RisingEdge(dut.clk)
            if dut.done.value:
                break
        if impos:
            if dut.result.value == 0b100000:
                passed += 1
            else:
                dut._log.error("Test failed: Expected IMPOSSIBLE")
        else:
            if dut.result.value[5] == 0 and dut.result.value[4:0] == length:
                passed += 1
            else:
                dut._log.error(f"Test failed: Expected {length} got {dut.result.value}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")"