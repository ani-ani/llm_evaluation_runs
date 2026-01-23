import cocotb
from cocotb.triggers import Timer

def str_to_64bit(s):
    """Convert up to 8-char string to 64-bit value (little-endian)"""
    if not s:
        return 0
    b = s.encode('ascii')
    val = 0
    for i, ch in enumerate(b):
        val |= ch << (i * 8)
    return val

def str_to_128bit(s):
    """Convert up to 16-char string to 128-bit value (little-endian)"""
    if not s:
        return 0
    b = s.encode('ascii')
    val_low = 0
    val_high = 0
    for i, ch in enumerate(b):
        if i < 8:
            val_low |= ch << (i * 8)
        else:
            val_high |= ch << ((i-8) * 8)
    return (val_high << 64) | val_low

@cocotb.test()
async def test_list_to_dict_converter(dut):
    """Test list to nested dictionary conversion"""
    
    # Test Case 1: Original test case from problem
    l1_1 = ["S001", "S002", "S003", "S004"]
    l2_1 = ["Adina Park", "Leyton Marsh", "Duncan Boyle", "Saim Richards"]
    l3_1 = [85, 98, 89, 92]
    
    # Test Case 2
    l1_2 = ["abc", "def", "ghi", "jkl"]
    l2_2 = ["python", "program", "language", "programs"]
    l3_2 = [100, 200, 300, 400]
    
    # Test Case 3
    l1_3 = ["A1", "A2", "A3", "A4"]
    l2_3 = ["java", "C", "C++", "DBMS"]
    l3_3 = [10, 20, 30, 40]
    
    # Test Case 4: Edge case - single character and empty-ish values
    l1_4 = ["X", "Y", "Z", "W"]
    l2_4 = ["a", "b", "c", "d"]
    l3_4 = [0, 1, 65535, 4294967295]
    
    test_cases = [
        (l1_1, l2_1, l3_1),
        (l1_2, l2_2, l3_2),
        (l1_3, l2_3, l3_3),
        (l1_4, l2_4, l3_4)
    ]
    
    passed = 0
    total = len(test_cases) * 4  # 4 entries per test case
    
    for test_idx, (l1, l2, l3) in enumerate(test_cases, 1):
        print(f"
Test Case {test_idx}:")
        
        # Convert to binary format
        l1_bin = [str_to_64bit(s) for s in l1]
        l2_bin = [str_to_128bit(s) for s in l2]
        
        # Apply inputs
        dut.l1_0.value = l1_bin[0]
        dut.l1_1.value = l1_bin[1]
        dut.l1_2.value = l1_bin[2]
        dut.l1_3.value = l1_bin[3]
        
        dut.l2_0.value = l2_bin[0]
        dut.l2_1.value = l2_bin[1]
        dut.l2_2.value = l2_bin[2]
        dut.l2_3.value = l2_bin[3]
        
        dut.l3_0.value = l3[0]
        dut.l3_1.value = l3[1]
        dut.l3_2.value = l3[2]
        dut.l3_3.value = l3[3]
        
        # Wait for combinational logic
        await Timer(10, units='ns')
        
        # Verify outputs
        for i in range(4):
            key = int(dut.result_key_i.value) if i == 0 else (int(dut.result_key_1.value) if i == 1 else (int(dut.result_key_2.value) if i == 2 else int(dut.result_key_3.value)))
            inner_key = int(dut.result_inner_key_i.value) if i == 0 else (int(dut.result_inner_key_1.value) if i == 1 else (int(dut.result_inner_key_2.value) if i == 2 else int(dut.result_inner_key_3.value)))
            value = int(dut.result_value_i.value) if i == 0 else (int(dut.result_value_1.value) if i == 1 else (int(dut.result_value_2.value) if i == 2 else int(dut.result_value_3.value)))
            
            # Check against expected
            exp_key = l1_bin[i]
            exp_inner = l2_bin[i]
            exp_value = l3[i]
            
            if key == exp_key and inner_key == exp_inner and value == exp_value:
                passed += 1
                print(f"  Entry {i}: PASS")
            else:
                print(f"  Entry {i}: FAIL")
                print(f"    Expected: key={hex(exp_key)}, inner={hex(exp_inner)}, value={exp_value}")
                print(f"    Got:      key={hex(key)}, inner={hex(inner_key)}, value={value}")
    
    print(f"
=== Summary: {passed}/{total} tests passed ===")
    assert passed == total, f"Only {passed}/{total} tests passed"
