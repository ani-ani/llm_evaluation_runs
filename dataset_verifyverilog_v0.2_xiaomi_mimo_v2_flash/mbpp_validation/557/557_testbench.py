import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_toggle_case(dut):
    """Test case toggling for 8-character fixed-width strings"""
    
    # Test 1: "Python" -> "pYTHON"
    # P=0x50, y=0x79, t=0x74, h=0x68, o=0x6F, n=0x6E
    # Expected: p=0x70, Y=0x59, T=0x54, H=0x48, O=0x4F, N=0x4E
    dut.char_0.value = 0x50  # 'P'
    dut.char_1.value = 0x79  # 'y'
    dut.char_2.value = 0x74  # 't'
    dut.char_3.value = 0x68  # 'h'
    dut.char_4.value = 0x6F  # 'o'
    dut.char_5.value = 0x6E  # 'n'
    dut.char_6.value = 0x20  # ' ' (space)
    dut.char_7.value = 0x20  # ' ' (space)
    
    await Timer(1, units='ns')
    
    assert dut.out_0.value == 0x70, f"Test 1 failed: out_0 = {hex(dut.out_0.value)}, expected 0x70"
    assert dut.out_1.value == 0x59, f"Test 1 failed: out_1 = {hex(dut.out_1.value)}, expected 0x59"
    assert dut.out_2.value == 0x54, f"Test 1 failed: out_2 = {hex(dut.out_2.value)}, expected 0x54"
    assert dut.out_3.value == 0x48, f"Test 1 failed: out_3 = {hex(dut.out_3.value)}, expected 0x48"
    assert dut.out_4.value == 0x4F, f"Test 1 failed: out_4 = {hex(dut.out_4.value)}, expected 0x4F"
    assert dut.out_5.value == 0x4E, f"Test 1 failed: out_5 = {hex(dut.out_5.value)}, expected 0x4E"
    assert dut.out_6.value == 0x20, f"Test 1 failed: out_6 = {hex(dut.out_6.value)}, expected 0x20"
    assert dut.out_7.value == 0x20, f"Test 1 failed: out_7 = {hex(dut.out_7.value)}, expected 0x20"
    
    # Test 2: "Pangram" -> "pANGRAM"
    # P=0x50, a=0x61, n=0x6E, g=0x67, r=0x72, a=0x61, m=0x6D
    # Expected: p=0x70, A=0x41, N=0x4E, G=0x47, R=0x52, A=0x41, M=0x4D
    dut.char_0.value = 0x50
    dut.char_1.value = 0x61
    dut.char_2.value = 0x6E
    dut.char_3.value = 0x67
    dut.char_4.value = 0x72
    dut.char_5.value = 0x61
    dut.char_6.value = 0x6D
    dut.char_7.value = 0x20
    
    await Timer(1, units='ns')
    
    assert dut.out_0.value == 0x70, f"Test 2 failed: out_0 = {hex(dut.out_0.value)}, expected 0x70"
    assert dut.out_1.value == 0x41, f"Test 2 failed: out_1 = {hex(dut.out_1.value)}, expected 0x41"
    assert dut.out_2.value == 0x4E, f"Test 2 failed: out_2 = {hex(dut.out_2.value)}, expected 0x4E"
    assert dut.out_3.value == 0x47, f"Test 2 failed: out_3 = {hex(dut.out_3.value)}, expected 0x47"
    assert dut.out_4.value == 0x52, f"Test 2 failed: out_4 = {hex(dut.out_4.value)}, expected 0x52"
    assert dut.out_5.value == 0x41, f"Test 2 failed: out_5 = {hex(dut.out_5.value)}, expected 0x41"
    assert dut.out_6.value == 0x4D, f"Test 2 failed: out_6 = {hex(dut.out_6.value)}, expected 0x4D"
    assert dut.out_7.value == 0x20, f"Test 2 failed: out_7 = {hex(dut.out_7.value)}, expected 0x20"
    
    # Test 3: "LIttLE" -> "liTTle"
    # L=0x4C, I=0x49, t=0x74, t=0x74, L=0x4C, E=0x45
    # Expected: l=0x6C, i=0x69, T=0x54, T=0x54, l=0x6C, e=0x65
    dut.char_0.value = 0x4C
    dut.char_1.value = 0x49
    dut.char_2.value = 0x74
    dut.char_3.value = 0x74
    dut.char_4.value = 0x4C
    dut.char_5.value = 0x45
    dut.char_6.value = 0x20
    dut.char_7.value = 0x20
    
    await Timer(1, units='ns')
    
    assert dut.out_0.value == 0x6C, f"Test 3 failed: out_0 = {hex(dut.out_0.value)}, expected 0x6C"
    assert dut.out_1.value == 0x69, f"Test 3 failed: out_1 = {hex(dut.out_1.value)}, expected 0x69"
    assert dut.out_2.value == 0x54, f"Test 3 failed: out_2 = {hex(dut.out_2.value)}, expected 0x54"
    assert dut.out_3.value == 0x54, f"Test 3 failed: out_3 = {hex(dut.out_3.value)}, expected 0x54"
    assert dut.out_4.value == 0x6C, f"Test 3 failed: out_4 = {hex(dut.out_4.value)}, expected 0x6C"
    assert dut.out_5.value == 0x65, f"Test 3 failed: out_5 = {hex(dut.out_5.value)}, expected 0x65"
    assert dut.out_6.value == 0x20, f"Test 3 failed: out_6 = {hex(dut.out_6.value)}, expected 0x20"
    assert dut.out_7.value == 0x20, f"Test 3 failed: out_7 = {hex(dut.out_7.value)}, expected 0x20"
    
    # Test 4: Mixed numbers and special chars "Abc123!" -> "aBC123!"
    dut.char_0.value = 0x41  # 'A'
    dut.char_1.value = 0x62  # 'b'
    dut.char_2.value = 0x63  # 'c'
    dut.char_3.value = 0x31  # '1'
    dut.char_4.value = 0x32  # '2'
    dut.char_5.value = 0x33  # '3'
    dut.char_6.value = 0x21  # '!'
    dut.char_7.value = 0x20  # ' '
    
    await Timer(1, units='ns')
    
    assert dut.out_0.value == 0x61, f"Test 4 failed: out_0 = {hex(dut.out_0.value)}, expected 0x61"
    assert dut.out_1.value == 0x42, f"Test 4 failed: out_1 = {hex(dut.out_1.value)}, expected 0x42"
    assert dut.out_2.value == 0x43, f"Test 4 failed: out_2 = {hex(dut.out_2.value)}, expected 0x43"
    assert dut.out_3.value == 0x31, f"Test 4 failed: out_3 = {hex(dut.out_3.value)}, expected 0x31"
    assert dut.out_4.value == 0x32, f"Test 4 failed: out_4 = {hex(dut.out_4.value)}, expected 0x32"
    assert dut.out_5.value == 0x33, f"Test 5 failed: out_5 = {hex(dut.out_5.value)}, expected 0x33"
    assert dut.out_6.value == 0x21, f"Test 6 failed: out_6 = {hex(dut.out_6.value)}, expected 0x21"
    assert dut.out_7.value == 0x20, f"Test 7 failed: out_7 = {hex(dut.out_7.value)}, expected 0x20"
    
    print("4/4 tests passed")