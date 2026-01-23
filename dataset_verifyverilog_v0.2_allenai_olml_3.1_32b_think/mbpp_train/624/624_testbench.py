import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

def ascii_to_bytes(s):
    """Convert string to list of bytes, padded with nulls to 8 chars"""
    result = [ord(c) for c in s]
    result.extend([0] * (8 - len(result)))
    return result

@cocotb.test()
async def test_string_to_upper(dut):
    """Test string to uppercase conversion"""
    
    # Test 1: "person" -> "PERSON"
    input_bytes = ascii_to_bytes("person")
    dut.input_string.value = input_bytes
    await Timer(1, units='ns')
    result_bytes = [int(dut.result[i].value) for i in range(8)]
    expected_bytes = ascii_to_bytes("PERSON")
    
    if result_bytes != expected_bytes:
        raise TestFailure(f"Test 1 failed: {input_bytes} -> {result_bytes}, expected {expected_bytes}")
    print(f"Test 1 passed: 'person' -> {''.join(chr(b) if b else '\\0' for b in result_bytes[:6])}")
    
    # Test 2: "final" -> "FINAL"
    input_bytes = ascii_to_bytes("final")
    dut.input_string.value = input_bytes
    await Timer(1, units='ns')
    result_bytes = [int(dut.result[i].value) for i in range(8)]
    expected_bytes = ascii_to_bytes("FINAL")
    
    if result_bytes != expected_bytes:
        raise TestFailure(f"Test 2 failed: {input_bytes} -> {result_bytes}, expected {expected_bytes}")
    print(f"Test 2 passed: 'final' -> {''.join(chr(b) if b else '\\0' for b in result_bytes[:5])}")
    
    # Test 3: "Valid" -> "VALID"
    input_bytes = ascii_to_bytes("Valid")
    dut.input_string.value = input_bytes
    await Timer(1, units='ns')
    result_bytes = [int(dut.result[i].value) for i in range(8)]
    expected_bytes = ascii_to_bytes("VALID")
    
    if result_bytes != expected_bytes:
        raise TestFailure(f"Test 3 failed: {input_bytes} -> {result_bytes}, expected {expected_bytes}")
    print(f"Test 3 passed: 'Valid' -> {''.join(chr(b) if b else '\\0' for b in result_bytes[:5])}")
    
    # Test 4: Mixed with numbers "a1B2" -> "A1B2"
    input_bytes = ascii_to_bytes("a1B2")
    dut.input_string.value = input_bytes
    await Timer(1, units='ns')
    result_bytes = [int(dut.result[i].value) for i in range(8)]
    expected_bytes = ascii_to_bytes("A1B2")
    
    if result_bytes != expected_bytes:
        raise TestFailure(f"Test 4 failed: {input_bytes} -> {result_bytes}, expected {expected_bytes}")
    print(f"Test 4 passed: 'a1B2' -> {''.join(chr(b) if b else '\\0' for b in result_bytes[:4])}")
    
    # Test 5: All lowercase "abcdefgh" -> "ABCDEFGH"
    input_bytes = ascii_to_bytes("abcdefgh")
    dut.input_string.value = input_bytes
    await Timer(1, units='ns')
    result_bytes = [int(dut.result[i].value) for i in range(8)]
    expected_bytes = ascii_to_bytes("ABCDEFGH")
    
    if result_bytes != expected_bytes:
        raise TestFailure(f"Test 5 failed: {input_bytes} -> {result_bytes}, expected {expected_bytes}")
    print(f"Test 5 passed: 'abcdefgh' -> {''.join(chr(b) for b in result_bytes)}")
    
    print(f"
All tests completed: 5/5 passed")