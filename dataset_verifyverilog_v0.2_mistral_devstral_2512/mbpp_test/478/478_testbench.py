import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_remove_lowercase(dut):
    """Test remove_lowercase module with various inputs"""
    
    # Helper function to convert string to inputs
    def setup_input(input_str):
        chars = [ord(c) for c in input_str]
        # Pad to 8 characters
        while len(chars) < 8:
            chars.append(0)
        
        dut.char0.value = chars[0]
        dut.char1.value = chars[1]
        dut.char2.value = chars[2]
        dut.char3.value = chars[3]
        dut.char4.value = chars[4]
        dut.char5.value = chars[5]
        dut.char6.value = chars[6]
        dut.char7.value = chars[7]
        dut.length.value = len(input_str)
    
    # Helper function to read output
    def read_output():
        out_chars = [
            int(dut.out0.value),
            int(dut.out1.value),
            int(dut.out2.value),
            int(dut.out3.value),
            int(dut.out4.value),
            int(dut.out5.value),
            int(dut.out6.value),
            int(dut.out7.value)
        ]
        out_len = int(dut.out_length.value)
        return ''.join([chr(c) if c != 0 else '' for c in out_chars[:out_len]]), out_len
    
    # Test 1: "PYTHon" -> "PYTH"
    setup_input("PYTHon")
    await Timer(1, units='ns')
    result, out_len = read_output()
    print(f"Test 1: Input='PYTHon', Expected='PYTH', Got='{result}' (len={out_len})")
    if result != "PYTH" or out_len != 4:
        raise TestFailure(f"Test 1 failed: expected 'PYTH' len=4, got '{result}' len={out_len}")
    
    # Test 2: "FInD" -> "FID"
    setup_input("FInD")
    await Timer(1, units='ns')
    result, out_len = read_output()
    print(f"Test 2: Input='FInD', Expected='FID', Got='{result}' (len={out_len})")
    if result != "FID" or out_len != 3:
        raise TestFailure(f"Test 2 failed: expected 'FID' len=3, got '{result}' len={out_len}")
    
    # Test 3: "STRinG" -> "STRG"
    setup_input("STRinG")
    await Timer(1, units='ns')
    result, out_len = read_output()
    print(f"Test 3: Input='STRinG', Expected='STRG', Got='{result}' (len={out_len})")
    if result != "STRG" or out_len != 4:
        raise TestFailure(f"Test 3 failed: expected 'STRG' len=4, got '{result}' len={out_len}")
    
    # Test 4: All uppercase "ABCD" -> "ABCD"
    setup_input("ABCD")
    await Timer(1, units='ns')
    result, out_len = read_output()
    print(f"Test 4: Input='ABCD', Expected='ABCD', Got='{result}' (len={out_len})")
    if result != "ABCD" or out_len != 4:
        raise TestFailure(f"Test 4 failed: expected 'ABCD' len=4, got '{result}' len={out_len}")
    
    # Test 5: All lowercase "abcd" -> "" (empty)
    setup_input("abcd")
    await Timer(1, units='ns')
    result, out_len = read_output()
    print(f"Test 5: Input='abcd', Expected='', Got='{result}' (len={out_len})")
    if result != "" or out_len != 0:
        raise TestFailure(f"Test 5 failed: expected '' len=0, got '{result}' len={out_len}")
    
    # Test 6: Mixed with numbers/symbols "Ab1!c" -> "Ab1!" (only lowercase removed)
    setup_input("Ab1!c")
    await Timer(1, units='ns')
    result, out_len = read_output()
    print(f"Test 6: Input='Ab1!c', Expected='Ab1!', Got='{result}' (len={out_len})")
    if result != "Ab1!" or out_len != 4:
        raise TestFailure(f"Test 6 failed: expected 'Ab1!' len=4, got '{result}' len={out_len}")
    
    print("
=== Summary ===")
    print("All 6 tests passed!")