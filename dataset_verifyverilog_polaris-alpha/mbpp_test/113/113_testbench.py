import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_integer_checker(dut):
    test_cases = [
        (['p','y','t','h','o','n',0,0], 6, 0),   # Test 1: Invalid
        (['1',0,0,0,0,0,0,0], 1, 1),            # Test 2: Valid
        (['1','2','3','4','5',0,0,0], 5, 1),     # Test 3: Valid
        ([0,0,0,0,0,0,0,0], 0, 0),              # Empty
        (['+',0,0,0,0,0,0,0], 1, 1),            # Single +
        (['-','1','2','3',0,0,0,0], 4, 1),      # Negative valid
        (['1','a',0,0,0,0,0,0], 2, 0)          # Invalid char
    ]
    passed = 0
    for chars, length, expected in test_cases:
        for i in range(8):
            dut.str[i].value = ord(chars[i]) if isinstance(chars[i], str) else chars[i]
        dut.length.value = length
        await Timer(1, units='ns')
        assert dut.is_integer.value == expected, f"Failed: {chars[:length]} -> {dut.is_integer.value} (expected {expected})"
        passed += 1
        dut._log.info(f"PASS: {chars[:length]}: {expected}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")