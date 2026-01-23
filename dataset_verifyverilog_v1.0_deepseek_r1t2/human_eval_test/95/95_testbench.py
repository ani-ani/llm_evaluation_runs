import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

# Helper function to pack 8 bytes into a 64-bit integer
def pack_string(s):
    """Pack a python string (max 8 chars) into 64-bit int, MSB first."""
    val = 0
    for i, char in enumerate(s):
        val |= (ord(char) << (56 - i*8))
    return val

# Helper function to check if value is defined
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

@cocotb.test(timeout_time=2, timeout_unit="ms")
async def test_check_dict_case(dut):
    """Test the check_dict_case module."""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.num_keys.value = 0
    for i in range(8):
        dut.keys[i].value = 0
    
    await RisingEdge(dut.clk)
    await Timer(1, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Define Test Cases
    # Format: (name, keys_list, num_keys, expected_result)
    # keys_list: list of strings (max 8 chars) or None (for invalid/non-string)
    
    test_cases = [
        ("All Lower", ["pineapple", "banana"], 2, 1),
        ("Mixed Case", ["pineapple", "Banana"], 2, 0),
        ("All Upper", ["STATE", "ZIP"], 2, 1),
        ("Empty Dict", [], 0, 0),
        ("Mixed Types", ["pineapple", None, "apple"], 3, 0),  # None simulates non-string key
        ("Invalid Char", ["Name", "Age"], 2, 0),
        ("Single Lower", ["fruit"], 1, 1),
        ("Single Upper", ["FRUIT"], 1, 1),
        ("Empty Keys", ["", ""], 2, 1),  # Null strings should be ok if consistent context (technically empty)
        ("Case Transition", ["apple", "BANANA"], 2, 0)
    ]
    
    passed = 0
    total = len(test_cases)
    
    for name, keys_list, num_keys, expected in test_cases:
        # Load inputs
        dut.num_keys.value = num_keys
        
        # Fill keys array (pack strings or 0 for invalid)
        for i in range(8):
            if i < len(keys_list):
                k = keys_list[i]
                if k is None:
                    dut.keys[i].value = 0
                else:
                    dut.keys[i].value = pack_string(k)
            else:
                dut.keys[i].value = 0
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout_cycles = 100
        done_found = False
        for _ in range(timeout_cycles):
            if not is_value_defined(dut.done.value):
                continue
            if dut.done.value == 1:
                done_found = True
                break
            await RisingEdge(dut.clk)
        
        if not done_found:
            raise TestFailure(f"Test '{name}': Timeout waiting for done signal")
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test '{name}': Result is undefined (X/Z)")
        
        result = int(dut.result.value)
        
        if result != expected:
            raise TestFailure(f"Test '{name}': Expected {expected}, got {result}")
        else:
            dut._log.info(f"Test '{name}' passed [OK]")
            passed += 1
            
        # Wait for next cycle to ensure clean state for next test
        await RisingEdge(dut.clk)
    
    dut._log.info(f"Summary: {passed}/{total} tests passed")
    if passed != total:
        raise TestFailure(f"Some tests failed. Passed: {passed}/{total}")