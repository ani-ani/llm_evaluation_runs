import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock

@cocotb.test()
async def test_histogram_max(dut):
    """Test histogram max frequency finder"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_in.value = 0
    await Timer(25, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Helper function to convert string to byte array
    def string_to_bytes(s):
        bytes_arr = [0] * 16
        for i, ch in enumerate(s[:16]):
            bytes_arr[i] = ord(ch)
        return bytes_arr
    
    # Helper to set input
    def set_input(s):
        byte_vals = string_to_bytes(s)
        for i in range(16):
            dut.char_in[i].value = byte_vals[i]
    
    # Helper to wait for done
    async def wait_for_done():
        for _ in range(20):  # Should complete within 18 cycles
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                return
        raise TimeoutError("Done signal not asserted within 20 cycles")
    
    # Test cases
    test_cases = [
        ("a b b a", 2, 0x000003),  # a=2, b=2
        ("a b c a b", 2, 0x000003),  # a=2, b=2, c=1
        ("a b c d g", 1, 0x00001B),  # a,b,c,d,g = 1 (bits 0,1,2,3,6)
        ("r t g", 1, 0x024800),  # r=18, t=19, g=6 -> bits 6,18,19
        ("b b b b a", 4, 0x000002),  # b=4, a=1
        ("", 0, 0),  # Empty string
        ("a", 1, 0x000001),  # Single character
        ("x x x x x x x x x", 9, 0x0200000),  # x=23, 9 times (exceeds 16 char limit, only 8 counted)
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (test_str, expected_max, expected_mask) in enumerate(test_cases):
        print(f"
Test {i+1}: '{test_str}'")
        
        # Set input
        set_input(test_str)
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        await wait_for_done()
        
        # Read results
        actual_max = int(dut.max_count.value)
        actual_mask = int(dut.max_letters.value)
        
        print(f"  Expected: count={expected_max}, mask=0x{expected_mask:07X}")
        print(f"  Actual:   count={actual_max}, mask=0x{actual_mask:07X}")
        
        # Verify
        if actual_max == expected_max and actual_mask == expected_mask:
            print("  ✓ PASS")
            passed += 1
        else:
            print("  ✗ FAIL")
            # Show which letters are set
            expected_letters = [chr(ord('a')+j) for j in range(26) if (expected_mask >> j) & 1]
            actual_letters = [chr(ord('a')+j) for j in range(26) if (actual_mask >> j) & 1]
            print(f"    Expected letters: {expected_letters}")
            print(f"    Actual letters: {actual_letters}")
    
    print(f"
{'='*50}")
    print(f"SUMMARY: {passed}/{total} tests passed")
    print(f"{'='*50}")
    
    assert passed == total, f"Only {passed} out of {total} tests passed"
