import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure
import random

@cocotb.test()
async def test_file_pattern_matcher(dut):
    """Test file pattern matching with wildcards"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.pattern_char.value = 0
    dut.file_char.value = 0
    dut.pattern_valid.value = 0
    dut.file_valid.value = 0
    dut.pattern_end.value = 0
    dut.file_end.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Test case 1: Pattern "*.*" matching "main.c"
    print("Test 1: Pattern '*.*' with file 'main.c'")
    await pattern_match_test(dut, "*.*", "main.c", True)
    
    # Test case 2: Pattern "*.*" matching "a.out"
    print("Test 2: Pattern '*.*' with file 'a.out'")
    await pattern_match_test(dut, "*.*", "a.out", True)
    
    # Test case 3: Pattern "*.*" matching "readme" (should fail - no extension)
    print("Test 3: Pattern '*.*' with file 'readme'")
    await pattern_match_test(dut, "*.*", "readme", False)
    
    # Test case 4: Pattern "*a*a*a" matching "aaa"
    print("Test 4: Pattern '*a*a*a' with file 'aaa'")
    await pattern_match_test(dut, "*a*a*a", "aaa", True)
    
    # Test case 5: Pattern "*a*a*a" matching "aaaaa"
    print("Test 5: Pattern '*a*a*a' with file 'aaaaa'")
    await pattern_match_test(dut, "*a*a*a", "aaaaa", True)
    
    # Test case 6: Pattern "*a*a*a" matching "abababa"
    print("Test 6: Pattern '*a*a*a' with file 'abababa'")
    await pattern_match_test(dut, "*a*a*a", "abababa", True)
    
    # Test case 7: Exact match without wildcards
    print("Test 7: Pattern 'test.c' with file 'test.c'")
    await pattern_match_test(dut, "test.c", "test.c", True)
    
    # Test case 8: No match without wildcards
    print("Test 8: Pattern 'test.c' with file 'test.h'")
    await pattern_match_test(dut, "test.c", "test.h", False)
    
    # Test case 9: Pattern with leading wildcard
    print("Test 9: Pattern '*.txt' with file 'readme.txt'")
    await pattern_match_test(dut, "*.txt", "readme.txt", True)
    
    # Test case 10: Pattern with only wildcards
    print("Test 10: Pattern '*' with file 'anything'")
    await pattern_match_test(dut, "*", "anything", True)
    
    print("All 10 tests completed!")

async def pattern_match_test(dut, pattern, filename, expected_match):
    """Helper function to test one pattern-file combination"""
    
    # Convert strings to ASCII lists
    pattern_bytes = [ord(c) for c in pattern]
    file_bytes = [ord(c) for c in filename]
    
    # Start the matching process
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Feed pattern and file characters sequentially
    pattern_idx = 0
    file_idx = 0
    pattern_done = False
    file_done = False
    
    # Maximum cycles to wait
    max_cycles = 30
    cycles = 0
    
    while cycles < max_cycles:
        await RisingEdge(dut.clk)
        cycles += 1
        
        # Check if module needs more characters
        if hasattr(dut, 'need_more_chars') and dut.need_more_chars.value:
            # Provide next pattern character if available
            if not pattern_done and pattern_idx < len(pattern_bytes):
                dut.pattern_char.value = pattern_bytes[pattern_idx]
                dut.pattern_valid.value = 1
                pattern_idx += 1
                if pattern_idx >= len(pattern_bytes):
                    pattern_done = True
                    dut.pattern_end.value = 1
            else:
                dut.pattern_valid.value = 0
                dut.pattern_end.value = 0 if not pattern_done else 1
            
            # Provide next file character if available
            if not file_done and file_idx < len(file_bytes):
                dut.file_char.value = file_bytes[file_idx]
                dut.file_valid.value = 1
                file_idx += 1
                if file_idx >= len(file_bytes):
                    file_done = True
                    dut.file_end.value = 1
            else:
                dut.file_valid.value = 0
                dut.file_end.value = 0 if not file_done else 1
        else:
            # Clear valid signals
            dut.pattern_valid.value = 0
            dut.file_valid.value = 0
        
        # Check if done
        if dut.done.value:
            result = bool(dut.match_result.value)
            if result != expected_match:
                raise TestFailure(f"Pattern '{pattern}' vs File '{filename}': Expected {expected_match}, got {result}")
            return
    
    # If we get here, module didn't finish in time
    raise TestFailure(f"Module did not complete within {max_cycles} cycles for pattern '{pattern}' file '{filename}'")
