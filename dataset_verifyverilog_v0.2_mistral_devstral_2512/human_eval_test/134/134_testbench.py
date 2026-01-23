import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock

@cocotb.test()
async def test_check_if_last_char_is_a_letter(dut):
    """Test the check_if_last_char_is_a_letter module"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.string_data.value = 0
    dut.string_len.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    def str_to_bytes(s):
        """Convert string to 128-bit packed bytes"""
        if len(s) > 16:
            raise ValueError("String too long, max 16 characters")
        # Pack characters: first char at bits [127:120], last at [7:0]
        val = 0
        for i, char in enumerate(s):
            ascii_val = ord(char)
            val |= (ascii_val << (120 - i*8))
        return val
    
    def run_test(string, expected):
        """Helper to run a single test case"""
        return string, expected
    
    test_cases = [
        run_test("apple", False),
        run_test("apple pi e", True),
        run_test("eeeee", False),
        run_test("A", True),
        run_test("Pumpkin pie ", False),
        run_test("Pumpkin pie 1", False),
        run_test("", False),
        run_test("eeeee e ", False),
        run_test("apple pie", False),
        run_test("apple pi e ", False),
        # Additional test cases
        run_test("x", True),
        run_test("x y", True),
        run_test("xy", False),
        run_test("a b c", True),
        run_test("test ", False),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for string, expected in test_cases:
        # Prepare inputs
        dut.string_data.value = str_to_bytes(string)
        dut.string_len.value = len(string)
        dut.start.value = 1
        
        # Wait for start to be registered
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (2 cycles total)
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        
        # Read result
        actual = bool(dut.result.value)
        done_signal = bool(dut.done.value)
        
        # Verify
        assert done_signal == True, f"Done signal not high for '{string}'"
        
        if actual == expected:
            passed += 1
            print(f"PASS: '{string}' → {actual} (expected {expected})")
        else:
            print(f"FAIL: '{string}' → {actual} (expected {expected})")
            assert False, f"Test failed for input '{string}'"
    
    print(f"
{passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"
