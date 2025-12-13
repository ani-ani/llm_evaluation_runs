import cocotb
from cocotb.triggers import Timer
import binascii

@cocotb.test()
async def test_count_std(dut):
    def str_to_bits(s):
        padded = s.ljust(16, '\\0')[:16]  # Pad/truncate to 16 chars
        return int.from_bytes(padded.encode(), 'big')
    
    # Adapted test cases (original values truncated/padded to 16 chars):
    test_cases = [
        ("letstdlenstdporstd",  3),  # Original len 17 -> truncate to "letstdlenstdpors" (count=2)
        ("truststdsolenspors", 1),  # Original "truststdsolensporsd" (len 18 -> truncate), count=1
        ("makestdsostdworth",  2),  # Len 16, count=2
        ("stds            ",  1),  # Pad with spaces
        ("",                  0)   # All zeros
    ]
    
    passed = 0
    for s, expected in test_cases:
        # Convert string to 128-bit representation
        dut.str.value = str_to_bits(s)
        await Timer(1, units='ns')
        result = dut.count.value.integer
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: '{s}' -> {result}")
        else:
            dut._log.error(f"FAIL: '{s}' -> {result}, expected {expected}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")