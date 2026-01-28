import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_substring_search(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset sequence
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Helper to write string to array
    def write_string(port, text, max_len=16):
        # Convert string to ASCII bytes
        bytes_list = [ord(c) for c in text[:max_len]]
        bytes_list.extend([0] * (max_len - len(bytes_list)))
        for i in range(max_len):
            getattr(dut, f'{port}[{i}]').value = bytes_list[i]
    
    # Helper to read array
    def read_string(port, max_len=16):
        result = []
        for i in range(max_len):
            val = int(getattr(dut, f'{port}[{i}]').value)
            if val == 0:
                break
            result.append(chr(val))
        return ''.join(result)
    
    async def wait_for_done(max_cycles=500):
        for _ in range(max_cycles):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                return True
        raise TestFailure("Timeout waiting for done")
    
    # Test cases
    test_cases = [
        # (text, pattern, expected_match, expected_start, expected_end, desc)
        ('python programming', 'python', 'python', 0, 6, "Test 1: First word match"),
        ('programming language', 'programming', 'programming', 0, 11, "Test 2: Word match"),
        ('c++ programming', 'python', None, 0, 0, "Test 3: No match"),
        ('ab', 'ab', 'ab', 0, 2, "Test 4: Complete match"),
        ('a', 'a', 'a', 0, 1, "Test 5: Single char match"),
        ('test', 'testing', None, 0, 0, "Test 6: Pattern longer than text"),
    ]
    
    passed = 0
    failed = 0
    
    for text, pattern, expected_match, expected_start, expected_end, desc in test_cases:
        cocotb.log.info(f"Running: {desc}")
        
        try:
            # Write test data
            write_string('text', text)
            write_string('pattern', pattern)
            
            # Set lengths
            if has_signal(dut, 'text_len'):
                dut.text_len.value = len(text)
            if has_signal(dut, 'pattern_len'):
                dut.pattern_len.value = len(pattern)
            
            # Start search
            await RisingEdge(dut.clk)
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for completion
            await wait_for_done()
            
            # Read results
            if not is_value_defined(dut.valid.value):
                raise TestFailure("Valid signal undefined")
            
            valid = int(dut.valid.value)
            
            if expected_match is None:
                # Should not match
                if valid != 0:
                    raise TestFailure(f"Expected no match, but found valid=1")
                if has_signal(dut, 'no_valid'):
                    if not is_value_defined(dut.no_valid.value):
                        raise TestFailure("no_valid signal undefined")
                    if int(dut.no_valid.value) != 1:
                        raise TestFailure(f"Expected no_valid=1, got {int(dut.no_valid.value)}")
                cocotb.log.info(f"  ✓ No match as expected")
            else:
                # Should match
                if valid != 1:
                    raise TestFailure(f"Expected valid=1, got {valid}")
                
                # Read matched substring
                match_str = read_string('match_substring')
                if match_str != expected_match:
                    raise TestFailure(f"Expected substring '{expected_match}', got '{match_str}'")
                
                # Read indices
                start_idx = int(dut.start_idx.value)
                end_idx = int(dut.end_idx.value)
                
                if start_idx != expected_start:
                    raise TestFailure(f"Expected start_idx={expected_start}, got {start_idx}")
                if end_idx != expected_end:
                    raise TestFailure(f"Expected end_idx={expected_end}, got {end_idx}")
                
                cocotb.log.info(f"  ✓ Found '{match_str}' at {start_idx}:{end_idx}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL {desc}: {e}")
            failed += 1
        
        # Reset between tests
        await RisingEdge(dut.clk)
        if has_signal(dut, 'rst_n'):
            dut.rst_n.value = 0
            await RisingEdge(dut.clk)
            dut.rst_n.value = 1
            await RisingEdge(dut.clk)
    
    if failed:
        raise TestFailure(f"{failed} of {passed + failed} tests failed")
    
    cocotb.log.info(f"All {passed} tests passed!")