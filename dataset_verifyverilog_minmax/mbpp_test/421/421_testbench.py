import cocotb
from cocotb.triggers import Timer
import binascii

@cocotb.test()
async def test_tuple_concat(dut):
    # Test cases adapted to byte arrays
    # Format: (elem1, elem2, elem3, elem4), expected string (hex representation)
    test_cases = [
        # Test 1: ("ID", "is", "4", "UTS")
        (0x494400, 0x697300, 0x34, 0x555453),  # 'ID-is-4-UTS'
        b'ID\x00-is\x00-4\x00\x00-UTS',
        
        # Test 2: ("QWE", "is", "4", "RTY")
        (0x515745, 0x697300, 0x34, 0x525459),  # 'QWE-is-4-RTY'
        b'QWE-is\x00-4\x00\x00-RTY',
        
        # Test 3: ("ZEN", "is", "4", "OP")
        (0x5A454E, 0x697300, 0x34, 0x4F5000),  # 'ZEN-is-4-OP'
        b'ZEN-is\x00-4\x00\x00-OP\x00'
    ]
    
    passed = 0
    for i in range(0, len(test_cases), 2):
        # Unpack inputs and expected output
        (e1, e2, e3, e4), expected_bytes = test_cases[i:i+2]
        
        # Apply inputs
        dut.elem1.value = e1
        dut.elem2.value = e2
        dut.elem3.value = e3
        dut.elem4.value = e4
        
        # Wait for combinational logic
        await Timer(1, units='ns')
        
        # Convert 120-bit output to 15 bytes
        result_bytes = dut.result.value.buff.tobytes()[:15]  # Get first 15 bytes
        
        try:
            # Compare actual vs expected
            assert result_bytes == expected_bytes, f"Mismatch:
Exp: {binascii.hexlify(expected_bytes)}
Got: {binascii.hexlify(result_bytes)}"
            passed += 1
            dut._log.info(f"Test {i//2} PASS")
        except AssertionError as e:
            dut._log.error(f"Test {i//2} FAIL: {e}")
    
    dut._log.info(f"
SUMMARY: {passed}/{len(test_cases)//2} tests passed")