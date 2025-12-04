import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_counter(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    test_cases = [
        # Test case 1: 3 names (IVO, JASNA->JAS, JOSIPA->JOS) - pad with space
        (["IVO ", "JASN", "JOSI", "    "], 4),
        # Test case 2: 4 names from second sample (scaled)
        (["MAR ", "MARA", "MART", "MAT "], 24),
        # Test case 3: All start with A
        (["A   ", "AA  ", "AAA ", "AAAA"], 8)
    ]
    passed = 0
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    for (names, expected) in test_cases:
        # Convert names to ASCII values
        for i in range(4):
            name_val = 0
            for j, c in enumerate(names[i].ljust(4)[:4]):
                name_val |= ord(c) << (j*8)
            dut.names[i].value = name_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        # Wait for 5 cycles
        for _ in range(7):  # Extra margin
            await RisingEdge(dut.clk)
        if dut.done.value == 1 and dut.count.value == expected:
            passed += 1
        else:
            dut._log.error(f"Failed: Expected {expected}, got {dut.count.value}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)