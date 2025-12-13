import cocotb
from cocotb.triggers import Timer
@cocotb.test()
async def test_min_jumps(dut):
    def fp16(val):
        return int(val * 256)
    test_cases = [
        # Original: (3,4,11) -> 3.5
        {"a":3, "b":4, "d":11, "exp": fp16(3.5)}, # 0x0380
        {"a":3, "b":4, "d":0, "exp": fp16(0)},   # 0x0000
        {"a":11, "b":14, "d":11, "exp": fp16(1)},# 0x0100
        {"a":5, "b":3, "d":2, "exp": fp16(2)}   # Modified case (swapped a/b) for min/max
    ]
    passed = 0
    for tc in test_cases:
        dut.a.value = tc["a"]
        dut.b.value = tc["b"]
        dut.d.value = tc["d"]
        await Timer(2, "ns")
        actual = dut.jumps.value.integer
        if actual == tc["exp"]:
            passed += 1
            dut._log.info(f"PASS: a={tc['a']} b={tc['b']} d={tc['d']} = 0x{actual:04x}")
        else:
            dut._log.error(f"FAIL: a={tc['a']} b={tc['b']} d={tc['d']} got 0x{actual:04x} != 0x{tc['exp']:04x}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")