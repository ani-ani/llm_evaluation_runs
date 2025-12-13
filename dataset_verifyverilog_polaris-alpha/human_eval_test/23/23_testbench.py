import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_string_length(dut):
    test_cases = [
        (0x00000000000000000000000000000000, 0),  # Empty string
        (0x78000000000000000000000000000000, 1),  # "x"
        (0x61736461736E616B6A00000000000000, 9),  # "asdasnakj"
        (0x61616161616161616161616161616161, 16), # All 'a's (no null terminator)
        (0x61620064656172670000000000000000, 2)   # "ab" followed by non-zero then zero
    ]
    passed = 0
    
    for string_val, expected in test_cases:
        dut.string_bytes.value = string_val
        await Timer(1, 'ns')  # Combinational delay
        result = dut.length.value
        if result == expected:
            passed += 1
        else:
            dut._log.error(f"Input: {string_val:#034x} -> Got {result}, Expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")