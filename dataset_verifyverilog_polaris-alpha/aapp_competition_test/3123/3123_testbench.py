import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from math import log2, floor

@cocotb.test()
async def test_quotations(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    # Test cases (scaled)
    tests = [
        # Original sample 1 (scaled)
        {'n':5, 'a':[2,1,1,1,3], 'expected':2},
        # Original sample 2 (scaled to 8)
        {'n':1, 'a':[8], 'expected':3},
        # Original sample 3
        {'n':1, 'a':[1], 'expected':0},
        # Additional test case
        {'n':1, 'a':[4], 'expected':2}
    ]
    passed = 0
    for t in tests:
        dut.start.value = 0
        dut.n.value = t['n']
        # Assign segments (0-7)
        for i in range(8):
            segment_val = t['a'][i] if (i < len(t['a'])) else 0
            if i == 0: dut.a0.value = segment_val
            elif i == 1: dut.a1.value = segment_val
            elif i == 2: dut.a2.value = segment_val
            elif i == 3: dut.a3.value = segment_val
            elif i == 4: dut.a4.value = segment_val
            elif i == 5: dut.a5.value = segment_val
            elif i == 6: dut.a6.value = segment_val
            elif i == 7: dut.a7.value = segment_val
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        # Wait up to 20 clocks for completion
        for _ in range(20):
            await RisingEdge(dut.clk)
            if dut.valid.value:
                break
        result = dut.k.value
        expected = t['expected']
        if result == expected:
            passed += 1
            dut._log.info(f"Test passed: n={t['n']} a={t['a']} -> {result}")
        else:
            dut._log.error(f"Test FAILED: n={t['n']} a={t['a']} -> {result}, expected {expected}")
    dut._log.info(f"{passed}/{len(tests)} tests passed")
    assert passed == len(tests)
