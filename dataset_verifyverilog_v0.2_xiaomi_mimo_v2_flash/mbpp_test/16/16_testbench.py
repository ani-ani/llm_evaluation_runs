import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

def char_to_ascii(c):
    return ord(c)

@cocotb.test()
async def test_text_lowercase_underscore(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid.value = 0
    dut.char_in.value = 0
    dut.char_index.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    async def validate_string(test_string, expected, test_name):
        print(f"
{test_name}: Testing '{test_string}'")
        
        # Pad string to 16 characters with null (0)
        padded = test_string + '\x00' * (16 - len(test_string))
        
        # Start validation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Feed characters
        for i in range(16):
            dut.char_in.value = char_to_ascii(padded[i])
            dut.char_index.value = i
            dut.valid.value = 1
            await RisingEdge(dut.clk)
        
        dut.valid.value = 0
        
        # Wait for completion (additional cycles for validation)
        await Timer(50, units="ns")
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        
        actual = bool(dut.result.value)
        done = bool(dut.done.value)
        
        print(f"  Expected: {expected}, Got: {actual}, Done: {done}")
        
        if not done:
            raise TestFailure(f"{test_name}: done signal not asserted")
        
        if actual != expected:
            raise TestFailure(f"{test_name}: Expected {expected} but got {actual}")
        
        return actual == expected
    
    passed = 0
    total = 0
    
    # Test 1: Valid pattern "aab_cbbbc"
    total += 1
    if await validate_string("aab_cbbbc", True, "Test 1"):
        passed += 1
    
    # Test 2: Invalid - uppercase "aab_Abbbc"
    total += 1
    if await validate_string("aab_Abbbc", False, "Test 2"):
        passed += 1
    
    # Test 3: Invalid - uppercase at start "Aaab_abbbc"
    total += 1
    if await validate_string("Aaab_abbbc", False, "Test 3"):
        passed += 1
    
    # Additional Test 4: Valid minimal "a_b"
    total += 1
    if await validate_string("a_b", True, "Test 4"):
        passed += 1
    
    # Additional Test 5: Invalid - no underscore "abc"
    total += 1
    if await validate_string("abc", False, "Test 5"):
        passed += 1
    
    # Additional Test 6: Invalid - trailing underscore "abc_"
    total += 1
    if await validate_string("abc_", False, "Test 6"):
        passed += 1
    
    # Additional Test 7: Valid with numbers? Should be false
    total += 1
    if await validate_string("ab1_cde", False, "Test 7"):
        passed += 1
    
    print(f"
{passed}/{total} tests passed")
