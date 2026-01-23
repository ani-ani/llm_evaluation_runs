import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock

@cocotb.test()
async def test_tuple_concat(dut):
    # Create a clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.str0.value = 0
    dut.str1.value = 0
    dut.str2.value = 0
    dut.str3.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: ("ID", "is", 4, "UTS") -> "ID-is-4-UTS"
    # Input mapping: Assuming fixed 4-byte width per element.
    # "ID" -> 0x49442020 ("ID  ")
    # "is" -> 0x69732020 ("is  ")
    # "4" -> 0x34202020 ("4   ")
    # "UTS" -> 0x55545320 ("UTS ")
    dut.str0.value = 0x49442020
    dut.str1.value = 0x69732020
    dut.str2.value = 0x34202020
    dut.str3.value = 0x55545320
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await RisingEdge(dut.clk) # Process
    
    assert dut.done.value == 1, "Done should be high"
    
    # Expected: "ID-is-4-UTS" followed by padding
    # "ID"(2) + '-'(1) + "is"(2) + '-'(1) + "4"(1) + '-'(1) + "UTS"(3) = 11 chars
    # 128-bit result contains these bytes.
    # Let's verify the first 11 bytes (assuming ASCII encoding in little-endian or big-endian byte order?)
    # Usually Verilog stores [127:0] where 127 is MSB. We will check packed value.
    # "ID" (0x4944), "is" (0x6973), "4" (0x34), "UTS" (0x555453)
    # Packed string (Big Endian byte order): 0x49 44 2D 69 73 2D 34 2D 55 54 53 ...
    # Hex: 0x49442D69732D342D5554...
    # We'll check the full 128-bit value against the expected padded value.
    # "ID-is-4-UTS" is 11 chars.
    # Hex for "ID-is-4-UTS" + null padding: 0x49442D69732D342D555453...
    # Let's construct the expected 128-bit integer.
    # Bytes (MSB first): 'I'(0x49), 'D'(0x44), '-'(0x2D), 'i'(0x69), 's'(0x73), '-'(0x2D), '4'(0x34), '-'(0x2D), 'U'(0x55), 'T'(0x54), 'S'(0x53).
    # Remaining bytes are zeros (padding).
    # Packed hex: 0x49442D69732D342D5554530000000000
    expected_val_1 = (0x49442D69732D342D5554530000000000)
    assert dut.result.value == expected_val_1, f"Test 1 Failed: Expected {hex(expected_val_1)}, Got {hex(int(dut.result.value))}"
    print(f"Test 1 Passed: {hex(int(dut.result.value))}")
    
    # Test Case 2: ("QWE", "is", 4, "RTY") -> "QWE-is-4-RTY"
    # "QWE" -> 0x51574520 ("QWE ")
    # "is" -> 0x69732020 ("is  ")
    # "4" -> 0x34202020 ("4   ")
    # "RTY" -> 0x52545920 ("RTY ")
    dut.str0.value = 0x51574520
    dut.str1.value = 0x69732020
    dut.str2.value = 0x34202020
    dut.str3.value = 0x52545920
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await RisingEdge(dut.clk)
    
    assert dut.done.value == 1, "Done should be high"
    # "QWE-is-4-RTY" -> Q(51) W(57) E(45) -(2D) i(69) s(73) -(2D) 4(34) -(2D) R(52) T(54) Y(59)
    expected_val_2 = (0x5157452D69732D342D52545900000000)
    assert dut.result.value == expected_val_2, f"Test 2 Failed: Expected {hex(expected_val_2)}, Got {hex(int(dut.result.value))}"
    print(f"Test 2 Passed: {hex(int(dut.result.value))}")
    
    # Test Case 3: ("ZEN", "is", 4, "OP") -> "ZEN-is-4-OP"
    # "ZEN" -> 0x5A454E20 ("ZEN ")
    # "is" -> 0x69732020 ("is  ")
    # "4" -> 0x34202020 ("4   ")
    # "OP" -> 0x4F502020 ("OP  ")
    dut.str0.value = 0x5A454E20
    dut.str1.value = 0x69732020
    dut.str2.value = 0x34202020
    dut.str3.value = 0x4F502020
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await RisingEdge(dut.clk)
    
    assert dut.done.value == 1, "Done should be high"
    # "ZEN-is-4-OP" -> Z(5A) E(45) N(4E) -(2D) i(69) s(73) -(2D) 4(34) -(2D) O(4F) P(50)
    expected_val_3 = (0x5A454E2D69732D342D4F502000000000)
    assert dut.result.value == expected_val_3, f"Test 3 Failed: Expected {hex(expected_val_3)}, Got {hex(int(dut.result.value))}"
    print(f"Test 3 Passed: {hex(int(dut.result.value))}")
    print("3/3 tests passed")
