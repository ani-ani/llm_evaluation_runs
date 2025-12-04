import cocotb
from cocotb.triggers import Timer

def pack_str(s):
    # Pack up to 8 chars into 64-bit value (LSByte first)
    packed = 0
    for i, c in enumerate(s[:8]):
        packed |= (ord(c) & 0xFF) << (i*8)
    return packed

@cocotb.test()
async def test_happy(dut):
    test_cases = [
        ("a",   0, False),
        ("aa",  2, False),
        ("abcd",4, True),
        ("aabb",4, False),
        ("adb", 3, True),
        ("xyy", 3, False),
        ("iopaxpoi", 8, True),
        ("iopaxioi", 8, False)  # Last 3 chars "ioi" are invalid
    ]
    passed = 0

    for s, length, expected in test_cases:
        dut.str_len.value = length
        dut.str_data.value = pack_str(s)
        await Timer(1, units='ns')  # Allow combinational logic
        
        if dut.happy.value == expected:
            passed += 1
            dut._log.info(f"PASS: '{s}' (len={length}) => {expected}")
        else:
            dut._log.error(f"FAIL: '{s}' (len={length}) => {dut.happy.value}, expected {expected}")
    
    dut._log.info(f"Final result: {passed}/{len(test_cases)} tests passed")