import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock

@cocotb.test()
async def test_remove_occurrences(dut):
    """Test removing first and last occurrence of character from 8-char string"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.target_char.value = 0
    dut.input_str.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 1: "hello" with 'l' -> "heo"
    print("
Test 1: 'hello' with 'l'")
    dut.input_str.value = 0x6f6c6c6568000000  # 'hello' + nulls
    dut.target_char.value = ord('l')  # 0x6c
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (18 cycles max)
    timeout = 20
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    result = dut.result_str.value
    # Extract non-zero bytes to form string
    result_bytes = []
    for i in range(8):
        byte_val = (result >> (i*8)) & 0xFF
        if byte_val != 0:
            result_bytes.append(chr(byte_val))
    result_str = ''.join(result_bytes)
    print(f"  Expected: 'heo', Got: '{result_str}'")
    assert result_str == "heo", f"Test 1 failed: expected 'heo', got '{result_str}'"
    print("  PASSED")
    
    # Wait for idle
    await RisingEdge(dut.clk)
    
    # Test 2: "abcda" with 'a' -> "bcd"
    print("
Test 2: 'abcda' with 'a'")
    dut.input_str.value = 0x6164636261000000  # 'abcda' + nulls
    dut.target_char.value = ord('a')  # 0x61
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 20
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    result = dut.result_str.value
    result_bytes = []
    for i in range(8):
        byte_val = (result >> (i*8)) & 0xFF
        if byte_val != 0:
            result_bytes.append(chr(byte_val))
    result_str = ''.join(result_bytes)
    print(f"  Expected: 'bcd', Got: '{result_str}'")
    assert result_str == "bcd", f"Test 2 failed: expected 'bcd', got '{result_str}'"
    print("  PASSED")
    
    await RisingEdge(dut.clk)
    
    # Test 3: "PHP" with 'P' -> "H"
    print("
Test 3: 'PHP' with 'P'")
    dut.input_str.value = 0x5048500000000000  # 'PHP' + nulls
    dut.target_char.value = ord('P')  # 0x50
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 20
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    result = dut.result_str.value
    result_bytes = []
    for i in range(8):
        byte_val = (result >> (i*8)) & 0xFF
        if byte_val != 0:
            result_bytes.append(chr(byte_val))
    result_str = ''.join(result_bytes)
    print(f"  Expected: 'H', Got: '{result_str}'")
    assert result_str == "H", f"Test 3 failed: expected 'H', got '{result_str}'"
    print("  PASSED")
    
    await RisingEdge(dut.clk)
    
    # Test 4: "nochar" with 'x' -> "nochar" (no change)
    print("
Test 4: 'nochar' with 'x' (no occurrence)")
    dut.input_str.value = 0x7261636f6e000000  # 'nochar' + nulls
    dut.target_char.value = ord('x')  # 0x78
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 20
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    result = dut.result_str.value
    result_bytes = []
    for i in range(8):
        byte_val = (result >> (i*8)) & 0xFF
        if byte_val != 0:
            result_bytes.append(chr(byte_val))
    result_str = ''.join(result_bytes)
    print(f"  Expected: 'nochar', Got: '{result_str}'")
    assert result_str == "nochar", f"Test 4 failed: expected 'nochar', got '{result_str}'"
    print("  PASSED")
    
    await RisingEdge(dut.clk)
    
    # Test 5: "aa" with 'a' -> "" (both removed)
    print("
Test 5: 'aa' with 'a' (remove both)")
    dut.input_str.value = 0x6161000000000000  # 'aa' + nulls
    dut.target_char.value = ord('a')  # 0x61
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 20
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    result = dut.result_str.value
    # Should be all zeros
    print(f"  Expected: empty, Got: 0x{result:016x}")
    assert result == 0, f"Test 5 failed: expected 0x0000000000000000, got 0x{result:016x}"
    print("  PASSED")
    
    print("
=== 5/5 tests passed ===")
