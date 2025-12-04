import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_triangle(dut):
    # Test cases: (input_a, input_h, expected_output)
    # Original decimal values -> Q8.8 conversion:
    # 5.0 = 5*256 = 1280, 3.0 = 3*256=768 -> 7.5 = 7.5*256=1920
    # 2.0=512, 2.0=512 -> 2.0=512
    # 10.0=2560, 8.0=2048 -> 40.0=10240
    test_cases = [
        (1280, 768, 1920),
        (512, 512, 512),
        (2560, 2048, 10240)
    ]
    passed = 0
    for a, h, expected in test_cases:
        dut.a.value = a
        dut.h.value = h
        await Timer(1, units='ns')
        actual = dut.area.value.integer
        if actual == expected:
            passed += 1
            dut._log.info(f"PASS: {a/256}+{h/256}={expected/256}")
        else:
            dut._log.error(f"FAIL: {a/256}*{h/256}={actual/256}, expected {expected/256}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")