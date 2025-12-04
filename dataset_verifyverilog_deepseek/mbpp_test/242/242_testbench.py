import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_counter(dut):
    test_cases = [
        (b"language\x00", 7),   # Original test adapted with null terminator
        (b"words\x00", 4),      # Short word
        (b"\x00", 0),           # Empty string
        (b"hardware_test\x00", 12),  # Longer string
        ([0xFF]*16, 15)          # No null case
    ]
    
    passed = 0
    for input_bytes, expected in test_cases:
        # Pad to 16 bytes with zeros
        padded_bytes = list(input_bytes) + [0]*(16-len(input_bytes)) if len(input_bytes) < 16 else list(input_bytes)
        
        # Apply inputs
        for i in range(16):
            dut.str_bytes[i].value = padded_bytes[i]
        
        await Timer(1, units='ns')
        
        if dut.count.value == expected:
            passed += 1
            dut._log.info(f"PASS: {input_bytes} -> {dut.count.value}")
        else:
            dut._log.error(f"FAIL: {input_bytes} -> {dut.count.value}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")