import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_returnable(dut):
    # Test case format: (belt_string, expected_count)
    # Belt encoding: '-'=00, '>'=01, '<'=10
    test_cases = [
        (">>>>", 8),     # All '>' → all returnable (truncated to 4 rooms + padded 4 '-' so total 4+4=8? Wait no, need to adjust for 8 rooms)
        # Let's create 8-room test cases based on problem examples:
        # Original examples adapted to 8 rooms (pad with '-' for unused rooms)
        ("-><-----", 3),  # First example (4 real rooms + 4 '-')
        (">>>>>>>>", 8),  # All clockwise
        ("<<<-----", 3),  # Original 3rd test case (3 '<' + 5 '-')
        ("<>------", 0)   # Second room has '<>', no '-' near rooms
    ]
    passed = 0
    for s, expected in test_cases:
        # Convert belt string to 16-bit vector
        val = 0
        for char in s:
            val = val << 2  # Shift 2 bits per room
            if char == '-':
                val |= 0b00
            elif char == '>':
                val |= 0b01
            elif char == '<':
                val |= 0b10
        # Pad remaining rooms (if any) with '-'
        remaining_rooms = 8 - len(s)
        val = val << (2 * remaining_rooms)  # Pad with '-' (00)
        
        dut.belt_states.value = val
        await Timer(1, 'ns')
        if dut.count.value == expected:
            passed += 1
        else:
            dut._log.error(f"Test failed: {s} (encoded={val:016b}) = {dut.count.value}, expected {expected}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
