import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_tuple_counter(dut):
    # Format: [elem3, elem2, elem1, elem0] (LSB first)
    # Tuple marker: 0b1xxxxxxx (MSB=1)
    test_cases = [
        # Original: (1,5,7,(4,6),10) → Keep 4 elements
        ([0b00000001, 0b00000111, 0b00000101, 0b10000110], 3),
        # Original: (2,9,(5,7),11) → 2 elements before tuple
        ([0b00001011, 0b10000111, 0b00001001, 0b00000010], 2),
        # Original: (11,15,5,8,(2,3),8) → First 4 elements
        ([0b00001000, 0b10000011, 0b00000101, 0b00001111], 3),
        # Edge case: tuple in first position
        ([0b10000000, 0b00000001, 0b00000010, 0b00000011], 0),
        # No tuple case
        ([0b00000000, 0b00000001, 0b00000010, 0b00000011], 4)
    ]
    passed = 0
    for data, expected in test_cases:
        dut.elements.value = (data[3] << 24) | (data[2] << 16) | (data[1] << 8) | data[0]
        await Timer(1, units='ns')
        if dut.count.value == expected:
            passed += 1
            dut._log.info(f"PASS: Input={data} → {expected}")
        else:
            dut._log.error(f"FAIL: {data} got {dut.count.value}, expected {expected}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")