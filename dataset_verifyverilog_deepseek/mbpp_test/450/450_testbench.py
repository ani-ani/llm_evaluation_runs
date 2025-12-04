import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_filter(dut):
    # Helper to pack strings
    def pack_str(s, length=16):
        s = s.ljust(length, '\\0')[:length]
        return int.from_bytes(s.encode('ascii'), 'little')
    
    test_cases = [
        # Test 1 (original test case)
        [
            ["Python", "list", "exercises", "practice", "solution"], 
            8, 
            ["practice", "solution"]
        ],
        # Test 2 (original test case)
        [
            ["Python", "list", "exercises", "practice", "solution"], 
            6, 
            ["Python"]
        ],
        # Test 3 (original test case)
        [
            ["Python", "list", "exercises", "practice", "solution"], 
            9, 
            ["exercises"]
        ]
    ]

    passed = 0
    for idx, (strings, target_len, expected) in enumerate(test_cases):
        # Pad test case to 8 strings with empty strings
        padded_strings = (strings + [""] * 8)[:8]
        
        # Apply inputs
        for i in range(8):
            setattr(dut, f"str{i}", pack_str(padded_strings[i]))
        dut.str_length.value = target_len
        
        await Timer(1, units='ns')
        
        errors = []
        # Check valid_mask
        expected_mask = 0
        for i, s in enumerate(padded_strings):
            should_match = (s in expected)
            actual = dut.valid_mask.value[i]
            
            if actual != int(should_match):
                errors.append(f"String {i} ({repr(s)}) valid incorrect: {actual} should be {int(should_match)}")
        
        # Check filtered outputs
        for i, s in enumerate(padded_strings):
            expected_val = pack_str(s) if s in expected else 0
            actual = getattr(dut, f"filtered{i}").value
            
            if actual != expected_val:
                errors.append(f"String {i} output mismatch: got {actual:x}, expected {expected_val:x}")
        
        if not errors:
            passed += 1
            dut._log.info(f"Test {idx+1} PASS")
        else:
            dut._log.error(f"Test {idx+1} FAIL
" + "
".join(errors))
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")