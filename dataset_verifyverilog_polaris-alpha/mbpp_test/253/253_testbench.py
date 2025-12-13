import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer

@cocotb.test()
async def test_integer_counter(dut):
    # Test cases: (input_bits, expected_count)
    test_cases = [(0b1100, 2), (0b1110, 3), (0b1010, 2)]
    passed = 0
    
    for is_int, expected in test_cases:
        dut.is_int.value = is_int
        await Timer(1, units='ns')
        if dut.count.value == expected:
            passed += 1
            dut._log.info(f"PASS: {bin(is_int)}→{expected}")
        else:
            dut._log.error(f"FAIL: {bin(is_int)}→{dut.count.value}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")