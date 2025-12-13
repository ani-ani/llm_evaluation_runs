import cocotb
from cocotb.triggers import Timer
from cocotb.types import LogicArray

@cocotb.test()
async def test_dict_checker(dut):
    test_cases = [
        # (key_count, keys, expected)
        (2, ['p', 'b', '\\0', '\\0'], 1),  # All lowercase
        (3, ['p', 'A', 'B', '\\0'], 0),     # Mixed case
        (3, ['5', 'a', 'a', '\\0'], 0),      # Non-letter
        (3, ['N', 'A', 'Z', '\\0'], 1),     # All uppercase
        (0, ['\\0','\\0','\\0','\\0'], 0), # Empty dict
        (4, ['C','I','T','Y'], 1)           # All uppercase full
    ]
    passed = 0
    for (count, keys, expected) in test_cases:
        # Convert string keys to ASCII bytes
        key_bytes = [ord(k) if isinstance(k, str) else 0 for k in keys]
        
        dut.key_count.value = count
        for i in range(4):
            getattr(dut, f"keys_{i}").value = key_bytes[i]
        
        await Timer(1, units='ns')
        result = dut.is_case_consistent.value
        
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: Count={count} Keys={keys} => {result}")
        else:
            dut._log.error(f"FAIL: Count={count} Keys={keys} => {result}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")