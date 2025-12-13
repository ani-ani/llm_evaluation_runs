import cocotb
from cocotb.triggers import Timer
import struct

# Q8.24 conversion helper
def float_to_q8_24(f):
    return int(f * (1 << 24)) & 0xFFFFFFFF

@cocotb.test()
async def test_closest(dut):
    # Convert test vectors 
    test_cases = [
        # Original: [1.0, 2.0, 3.9, 4.0, 5.0, 2.2] + [1000,1000] padding
        ([1.0, 2.0, 3.9, 4.0, 5.0, 2.2, 1000.0, 1000.0], (3.9, 4.0)),
        # Original: [1.0, 2.0, 5.9, 4.0, 5.0] + [1000]*3 padding
        ([1.0, 2.0, 5.9, 4.0, 5.0, 1000.0, 1000.0, 1000.0], (5.0, 5.9)),
        # Original: [1.0, 2.0, 3.0, 4.0, 5.0, 2.2] + [1000]*2
        ([1.0, 2.0, 3.0, 4.0, 5.0, 2.2, 1000.0, 1000.0], (2.0, 2.2)),
        # Original: [1.0, 2.0, 3.0, 4.0, 5.0, 2.0] + [1000]*2
        ([1.0, 2.0, 3.0, 4.0, 5.0, 2.0, 1000.0, 1000.0], (2.0, 2.0)),
        # Original: [1.1, 2.2, 3.1, 4.1, 5.1] + [1000]*3
        ([1.1, 2.2, 3.1, 4.1, 5.1, 1000.0, 1000.0, 1000.0], (2.2, 3.1))
    ]

    passed = 0
    for numbers, expected in test_cases:
        # Pack inputs
        packed = 0
        for n in reversed(numbers):
            packed = (packed << 32) | float_to_q8_24(n)
        dut.numbers_packed.value = packed
        
        await Timer(1, 'ns')  # Combinational logic settle time
        
        # Extract result
        result = dut.closest_pair.value
        out_lo = result & 0xFFFFFFFF
        out_hi = (result >> 32) & 0xFFFFFFFF
        actual = (
            struct.unpack('!f', struct.pack('!I', out_lo & 0xFFFFFFFF))[0],  
            struct.unpack('!f', struct.pack('!I', out_hi & 0xFFFFFFFF))[0]
        )
        
        # Compare rounded to 0.0001 precision due to FP conversion
        tol = 0.0001
        if (abs(actual[0] - expected[0]) < tol and abs(actual[1] - expected[1]) < tol):
            passed += 1
            dut._log.info(f"PASS: {numbers} -> {actual}")
        else:
            dut._log.error(f"FAIL: {numbers} -> {actual}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")