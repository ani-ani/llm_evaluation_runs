import cocotb
from cocotb.triggers import Timer
import random

def pack_hint(l, r, same):
    return ((l-1) << 4) | ((r-1) << 1) | (1 if same else 0)

@cocotb.test()
async def test_counter(dut):
    # Test case 1: 5 problems, 2 hints (expect 4)
    hints1 = (pack_hint(2,4,True), pack_hint(3,5,True))
    packed1 = sum(h << (7*i) for i,h in enumerate(hints1))
    dut.n.value = 5
    dut.m.value = 2
    dut.hints_packed.value = packed1
    await Timer(1, units='ns')
    assert dut.valid_count.value == 4, f"Test 1 failed: {dut.valid_count.value} != 4"

    # Test case 2: 5 problems, 3 hints (conflict, expect 0)
    hints2 = (pack_hint(1,3,True), pack_hint(2,5,True), pack_hint(1,5,False))
    packed2 = sum(h << (7*i) for i,h in enumerate(hints2))
    dut.n.value = 5
    dut.m.value = 3
    dut.hints_packed.value = packed2
    await Timer(1, units='ns')
    assert dut.valid_count.value == 0, f"Test 2 failed: {dut.valid_count.value} != 0"

    # Edge case: n=1, same hint should yield 2 solutions
    dut.n.value = 1
    dut.m.value = 1
    dut.hints_packed.value = pack_hint(1,1,True)
    await Timer(1, units='ns')
    assert dut.valid_count.value == 2, f"Edge test failed: {dut.valid_count.value} != 2"

    dut._log.info("3/3 tests passed")