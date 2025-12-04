import cocotb
from cocotb.triggers import Timer
import struct

@cocotb.test()
async def test_splitter(dut):
    test_cases = [
        (b'python\x00\x00', 6, [b'p',b'y',b't',b'h',b'o',b'n']),
        (b'Name\x00\x00\x00\x00', 4, [b'N',b'a',b'm',b'e']),
        (b'program\x00', 7, [b'p',b'r',b'o',b'g',b'r',b'a',b'm']) 
    ]
    
    passed = 0
    
    for packed_str, length, expected_chars in test_cases:
        # Convert string to 64-bit packed format
        packed = struct.unpack(">Q", packed_str.ljust(8, b'\x00'))[0]
        dut.packed_string.value = packed
        dut.len.value = length
        
        await Timer(1, units='ns')
        
        # Check all characters
        valid = True
        for i in range(8):
            char = bytes([dut.__getattr__(f"char{i}").value])
            
            if i < length:
                expected = expected_chars[i]
                mask_bit = 1 << i
                
                # Check character match
                if char != expected:
                    dut._log.error(f"Position {i}: Got {char} expected {expected}")
                    valid = False
                # Check valid mask
                if not (dut.valid_mask.value & mask_bit):
                    dut._log.error(f"Position {i}: Valid bit not set")
                    valid = False
            else:
                # Check invalid positions
                if char != b'\x00':
                    dut._log.error(f"Position {i}: Should be null byte")
                    valid = False
                if (dut.valid_mask.value >> i) & 1:
                    dut._log.error(f"Position {i}: Valid bit improperly set")
                    valid = False
        
        if valid:
            passed += 1
            dut._log.info(f"PASS: {packed_str[:length]} split correctly")
        else:
            dut._log.error(f"FAIL: {packed_str[:length]} split failed")
    
    dut._log.info(f"PASSED {passed}/{len(test_cases)} tests")
    assert passed == len(test_cases)