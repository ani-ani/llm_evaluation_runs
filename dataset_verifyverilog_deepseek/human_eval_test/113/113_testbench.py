import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_odd_counter(dut):
    test_cases = [
        (b"12345670", 4),
        (b"30000000", 1),
        (b"11111111", 8),
        (b"27100000", 2),
        (b"13700000", 3),
        (b"31400000", 2)
    ]
    passed = 0
    
    for data, expected in test_cases:
        # Pad to 8 bytes if needed
        padded = data.ljust(8, b'0')[:8]
        dut.str_i.value = int.from_bytes(padded, byteorder='big')
        
        await Timer(1, units='ns')
        
        if dut.count.value == expected:
            passed += 1
            dut._log.info(f"PASS: {padded} → {dut.count.value}")
        else:
            dut._log.error(f"FAIL: {padded} → {dut.count.value}, expected {expected}")
    
    total = len(test_cases)
    dut._log.info(f"{passed}/{total} tests passed")
    assert passed == total, f"Failed {total-passed} tests"