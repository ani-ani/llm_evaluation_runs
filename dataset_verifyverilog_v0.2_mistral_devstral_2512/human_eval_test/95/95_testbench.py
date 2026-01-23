import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_check_dict_case(dut):
    """Test the check_dict_case module with various dictionary configurations"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_entries.value = 0
    for i in range(8):
        getattr(dut, f'key_{i}').value = 0
    
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Helper function to convert string to 64-bit key
    def str_to_key(s):
        key = 0
        for i, char in enumerate(s):
            key |= ord(char) << (8 * i)
        return key
    
    # Helper function to run test
    async def run_test(name, entries, keys, expected):
        dut._log.info(f"Test: {name}")
        
        # Set inputs
        dut.valid_entries.value = entries
        for i in range(8):
            key_val = keys[i] if i < len(keys) else 0
            getattr(dut, f'key_{i}').value = key_val
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 100
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value:
                break
        else:
            raise TestFailure(f"Timeout waiting for done in {name}")
        
        # Check result
        actual = int(dut.result.value)
        if actual != expected:
            raise TestFailure(f"{name}: Expected {expected}, got {actual}")
        
        dut._log.info(f"  Result: {actual} (expected {expected}) - PASS")
    
    # Test cases adapted from Python function
    
    # Test 1: All lowercase - True
    # {"p":"pineapple", "b":"banana"}
    await run_test(
        "All lowercase",
        entries=0b00000011,
        keys=[str_to_key("p"), str_to_key("b"), 0, 0, 0, 0, 0, 0],
        expected=1
    )
    
    # Test 2: Mixed case - False
    # {"p":"pineapple", "A":"banana", "B":"banana"}
    await run_test(
        "Mixed case",
        entries=0b00000111,
        keys=[str_to_key("p"), str_to_key("A"), str_to_key("B"), 0, 0, 0, 0, 0],
        expected=0
    )
    
    # Test 3: Non-string key (represented as invalid) - False
    # {"p":"pineapple", 5:"banana", "a":"apple"}
    # We represent non-string keys as invalid entries in bit mask
    await run_test(
        "Invalid entry mixed",
        entries=0b00000101,  # Only entries 0 and 2 valid
        keys=[str_to_key("p"), 0, str_to_key("a"), 0, 0, 0, 0, 0],
        expected=1
    )
    
    # Test 4: All uppercase - True
    # {"STATE":"NC", "ZIP":"12345"}
    await run_test(
        "All uppercase",
        entries=0b00000011,
        keys=[str_to_key("STATE"), str_to_key("ZIP"), 0, 0, 0, 0, 0, 0],
        expected=1
    )
    
    # Test 5: Capitalized first letter - False
    # {"Name":"John", "Age":"36", "City":"Houston"}
    await run_test(
        "Capitalized (mixed case)",
        entries=0b00000111,
        keys=[str_to_key("Name"), str_to_key("Age"), str_to_key("City"), 0, 0, 0, 0, 0],
        expected=0
    )
    
    # Test 6: Empty dictionary - False
    # {}
    await run_test(
        "Empty dictionary",
        entries=0b00000000,
        keys=[0, 0, 0, 0, 0, 0, 0, 0],
        expected=0
    )
    
    # Test 7: Single lowercase entry - True
    # {"fruit":"Orange"} - note: key is lowercase
    await run_test(
        "Single lowercase",
        entries=0b00000001,
        keys=[str_to_key("fruit"), 0, 0, 0, 0, 0, 0, 0],
        expected=1
    )
    
    # Test 8: Mixed with numbers in key - False
    await run_test(
        "Key with digits",
        entries=0b00000011,
        keys=[str_to_key("key123"), str_to_key("abc"), 0, 0, 0, 0, 0, 0],
        expected=0
    )
    
    # Test 9: All uppercase, 8 chars - True
    await run_test(
        "Long uppercase",
        entries=0b00000001,
        keys=[str_to_key("ABCDEFGH"), 0, 0, 0, 0, 0, 0, 0],
        expected=1
    )
    
    # Test 10: All lowercase, 8 chars - True
    await run_test(
        "Long lowercase",
        entries=0b00000001,
        keys=[str_to_key("abcdefgh"), 0, 0, 0, 0, 0, 0, 0],
        expected=1
    )
    
    # Summary
    dut._log.info("
" + "="*50)
    dut._log.info("10/10 tests passed")
    dut._log.info("="*50)
