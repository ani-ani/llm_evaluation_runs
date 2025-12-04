import cocotb
from cocotb.triggers import Timer

def string_to_bytes(s, max_len=8):
    padded = s.ljust(max_len)
    return int.from_bytes(padded.encode('ascii'), 'big')

@cocotb.test()
async def test_extract_rear(dut):
    test_cases = [
        # Test 1 (3 strings)
        {
            'str': [
                string_to_bytes("Mers"), 
                string_to_bytes("for"),
                string_to_bytes("Vers"),
                0],
            'len': [4, 3, 4, 0],
            'expected': [ord('s'), ord('r'), ord('s'), 0]
        },
        # Test 2 (3 strings)
        {
            'str': [
                string_to_bytes("Avenge"),
                string_to_bytes("for"),
                string_to_bytes("People"),
                0],
            'len': [6, 3, 6, 0],
            'expected': [ord('e'), ord('r'), ord('e'), 0]
        },
        # Test 3 (3 strings)
        {
            'str': [
                string_to_bytes("Gotta"),
                string_to_bytes("get"),
                string_to_bytes("go"),
                0],
            'len': [5, 3, 2, 0],
            'expected': [ord('a'), ord('t'), ord('o'), 0]
        },
        # Edge case: empty string
        {
            'str': [0, 0, 0, 0],
            'len': [0, 0, 0, 0],
            'expected': [0, 0, 0, 0]
        }
    ]
    
    passed = 0
    for case in test_cases:
        for i in range(4):
            getattr(dut, f"str{i}").value = case['str'][i]
            getattr(dut, f"len{i}").value = case['len'][i]
        await Timer(1, units='ns')
        
        errors = []
        for i in range(4):
            actual = getattr(dut, f"rear{i}").value
            expected = case['expected'][i]
            if actual != expected:
                errors.append(f"str{i}: 0x{actual:02x} != 0x{expected:02x}")
        
        if not errors:
            passed += 1
            dut._log.info(f"PASS: {case['expected']}")
        else:
            dut._log.error(f"FAIL: {'; '.join(errors)}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")