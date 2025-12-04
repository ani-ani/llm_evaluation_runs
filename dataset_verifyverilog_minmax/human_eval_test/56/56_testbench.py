import cocotb
from cocotb.triggers import Timer
@cocotb.test()
async def test_brackets(dut):
    test_cases = [
        (
            # Test case 1: Valid pair "<>"
            0b0100000000000000, 
            1,
            "<>"
        ),
        (
            # Test case 2: Valid "<<><>>" (0b000101)
            0b0001010000000000, 
            1,
            "<<><>> (truncated to 6 chars via padding)"
        ),
        (
            # Test case 3: Invalid "><<>" (0b1101)
            0b1101000000000000, 
            0,
            "><<>"
        ),
        (
            # Test case 4: Terminal < 
            0b0000000000000000, 
            0,
            "<<<<<<<<<<<<<<<<"
        ),
        (
            # Test case 5: Perfectly balanced
            0b0101010101010101, 
            1,
            "<><><><><><><><>"
        )
    ]
    passed = 0
    for brackets, expected, name in test_cases:
        dut.brackets.value = brackets
        await Timer(1, units='ns')
        actual = dut.result.value
        if actual == expected:
            passed += 1
            dut._log.info(f"PASS: {name} → {expected}")
        else:
            dut._log.error(f"FAIL: {name} → got {actual}, expected {expected}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")