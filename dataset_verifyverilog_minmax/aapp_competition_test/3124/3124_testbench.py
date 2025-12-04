import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_ivana(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    test_cases = [
        (3, [3,1,5], 3),
        (4, [1,2,3,4], 2),
        (8, [4,10,5,2,9,8,1,7], 5)
    ]
    passed = 0
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    for n, numbers, expected in test_cases:
        dut.n.value = n
        for i in range(8):
            dut.nums[i].value = numbers[i] if i < len(numbers) else 0
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        while not dut.done.value:
            await RisingEdge(dut.clk)
        result = dut.win_count.value
        if result == expected:
            passed += 1
        else:
            dut._log.error(f"Failed: n={n}, nums={numbers} => {result} (expected {expected})")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
