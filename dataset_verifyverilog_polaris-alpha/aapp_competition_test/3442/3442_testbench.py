import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_sheldon(dut):
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    # Test cases (scaled to 16-bit)
    test_ranges = [
        (1, 10, 10),  # Original sample
        (70, 75, 1)    # 73 (1001001) valid
    ]
    await Timer(5, units='ns')
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    passed = 0
    for (x, y, expected) in test_ranges:
        count = 0
        for n in range(x, y+1):
            dut.start.value = 0
            dut.num.value = n
            await RisingEdge(dut.clk)
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            # Wait 16 cycles for processing
            for _ in range(16):
                await RisingEdge(dut.clk)
            if dut.done.value == 1 and dut.is_sheldon.value == 1:
                count += 1
            await RisingEdge(dut.clk)
        if count == expected:
            passed += 1
        else:
            dut._log.error(f"Range {x}-{y}: Got {count}, expected {expected}")
    total = len(test_ranges)
    dut._log.info(f"{passed}/{total} test ranges passed")
    assert passed == total, "Some test ranges failed"