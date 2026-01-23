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

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_palindrome_search(dut):
    """Test the palindrome search module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (input_string, expected_substring)
    test_cases = [
        ("where are the abaaba palindromes on this line", "abaaba"),
        ("none on this line", ""),
        ("how about this aaaaaaabbbbbbbbbbbbbbbbba", "abbbbbbbbbbbbbbbbba"),
        ("even a single a or b is a palindrome", "a"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_str, expected) in enumerate(test_cases):
        dut._log.info(f'Test {i+1}: {input_str}')
        
        # Prepare input
        length = len(input_str)
        if length > 50:
            dut._log.error(f'Input too long: {length} > 50')
            failed += 1
            continue
        
        # Assign characters individually (MANDATORY)
        for idx in range(50):
            port_name = f'char_{idx}'
            if has_signal(dut, port_name):
                if idx < length:
                    getattr(dut, port_name).value = ord(input_str[idx])
                else:
                    getattr(dut, port_name).value = 0
        
        # Set length
        if has_signal(dut, 'length'):
            dut.length.value = length
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        done_seen = False
        for _ in range(10000):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done_seen = True
                break
        
        if not done_seen:
            dut._log.error(f'Test {i+1}: Timeout waiting for done')
            failed += 1
            continue
        
        # Read result
        if not (has_signal(dut, 'result_start') and has_signal(dut, 'result_len')):
            dut._log.error('Result signals not found')
            failed += 1
            continue
        
        result_start = int(dut.result_start.value)
        result_len = int(dut.result_len.value)
        
        # Get actual substring
        if result_len == 0:
            actual = ""
        else:
            actual = input_str[result_start:result_start+result_len]
        
        # Compare
        if actual == expected:
            dut._log.info(f'  PASS: got "{actual}"')
            passed += 1
        else:
            dut._log.error(f'  FAIL: expected "{expected}", got "{actual}"')
            failed += 1
    
    # Summary
    dut._log.info(f'\n{"="*50}')
    dut._log.info(f'Results: {passed}/{passed+failed} tests passed')
    
    if failed > 0:
        raise TestFailure(f'{failed} tests failed')