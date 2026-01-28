import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_palindrome_cutter(dut):
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (input_string, expected_k, expected_palindromes)
    test_cases = [
        ("aabaac", 2, ["aba", "aca"]),
        ("0rTrT022", 1, ["02TrrT20"]),
        ("aA", 2, ["a", "A"]),
        ("a", 1, ["a"]),
        ("ff", 1, ["ff"]),
        ("9E", 2, ["9", "E"]),
        ("RRR", 1, ["RRR"]),
    ]
    
    for test_idx, (input_str, expected_k, expected_pal_list) in enumerate(test_cases):
        n = len(input_str)
        dut._log.info(f"Test {test_idx+1}: Input='{input_str}', Expected k={expected_k}")
        
        # Reset before each test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Feed input string
        dut.start.value = 1
        dut.len.value = n
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        for i, char in enumerate(input_str):
            dut.char_in.value = ord(char)
            await RisingEdge(dut.clk)
        
        # Wait for computation
        for _ in range(1000):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        
        if not dut.done.value:
            raise TestFailure(f"Test {test_idx+1}: Did not finish")
        
        # Check k
        k_val = int(dut.k.value)
        if k_val != expected_k:
            raise TestFailure(f"Test {test_idx+1}: Expected k={expected_k}, got {k_val}")
        
        # Check palindromes
        for i in range(k_val):
            pal_len = int(dut.palindrome_len[i].value)
            if pal_len == 0:
                continue
            
            # Read palindrome from memory
            pal_chars = []
            for j in range(pal_len):
                if is_value_defined(dut.palindrome_mem[i][j].value):
                    char_val = chr(int(dut.palindrome_mem[i][j].value))
                    pal_chars.append(char_val)
            pal_str = ''.join(pal_chars)
            
            if pal_str not in expected_pal_list:
                raise TestFailure(f"Test {test_idx+1}: Unexpected palindrome '{pal_str}'")
            
            # Remove found palindrome to avoid duplicates
            if pal_str in expected_pal_list:
                expected_pal_list.remove(pal_str)
        
        dut._log.info(f"  PASS: k={k_val}, palindromes checked")
    
    dut._log.info("All tests passed!")