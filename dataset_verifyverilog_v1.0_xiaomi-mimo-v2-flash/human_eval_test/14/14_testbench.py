import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except (ValueError, TypeError):
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except (ValueError, TypeError):
        return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def set_string_input(dut, test_string):
    """Set string input and character count"""
    # Get string length
    char_count = len(test_string)
    
    # Set each character in string_in array
    for i in range(8):
        if i < char_count:
            # Convert character to ASCII
            char_val = ord(test_string[i])
            dut.string_in[i].value = clamp_to_width(char_val, 8)
        else:
            # Pad with zeros
            dut.string_in[i].value = 0
    
    # Set character count
    dut.char_count.value = clamp_to_width(char_count, 4)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_all_prefixes(dut):
    """Test the all_prefixes module"""
    
    # Check if sequential module
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        # Setup clock (10ns period = 100MHz)
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    
    # Test cases from the problem
    test_cases = [
        ('', [], "empty string"),
        ('a', [1], "single char"),
        ('ab', [1, 2], "two chars"),
        ('abc', [1, 2, 3], "three chars"),
        ('asdfgh', [1, 2, 3, 4, 5, 6], "six chars"),
        ('WWW', [1, 2, 3], "repeated chars"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (inp_str, expected_lengths, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        
        try:
            # Set up input string
            if is_seq:
                await set_string_input(dut, inp_str)
                
                # Trigger computation
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut)
                
                # Check done signal
                if not is_value_defined(dut.done.value):
                    raise TestFailure("Done signal undefined")
                if int(dut.done.value) != 1:
                    raise TestFailure(f"Done signal not set, got {int(dut.done.value)}")
                
                # Read valid_count
                if not is_value_defined(dut.valid_count.value):
                    raise TestFailure("Valid_count signal undefined")
                valid_count = int(dut.valid_count.value)
                
                # Check valid_count matches expected
                if valid_count != len(expected_lengths):
                    raise TestFailure(f"Valid count mismatch: expected {len(expected_lengths)}, got {valid_count}")
                
                # Read prefix lengths
                expected_prefixes = expected_lengths + [0] * (8 - len(expected_lengths))
                
                for j in range(8):
                    if has_signal(dut, f'prefixes_{j}'):
                        # Individual port access
                        port_val = getattr(dut, f'prefixes_{j}').value
                        if not is_value_defined(port_val):
                            raise TestFailure(f"prefixes_{j} undefined")
                        prefix_val = int(port_val)
                        if prefix_val != expected_prefixes[j]:
                            raise TestFailure(f"prefixes[{j}] mismatch: expected {expected_prefixes[j]}, got {prefix_val}")
                    elif has_signal(dut, 'prefixes'):
                        # Array access
                        if hasattr(dut.prefixes, '__getitem__'):
                            prefix_val = int(dut.prefixes[j].value)
                            if prefix_val != expected_prefixes[j]:
                                raise TestFailure(f"prefixes[{j}] mismatch: expected {expected_prefixes[j]}, got {prefix_val}")
                        else:
                            raise TestFailure("Cannot access prefixes as array")
                    else:
                        raise TestFailure("prefixes signal not found")
                
            else:
                # Combinational - just set inputs
                await set_string_input(dut, inp_str)
                await Timer(100, units='ns')
                
                # For combinational, check prefixes immediately
                valid_count = int(dut.valid_count.value) if is_value_defined(dut.valid_count.value) else 0
                
                if valid_count != len(expected_lengths):
                    raise TestFailure(f"Valid count mismatch: expected {len(expected_lengths)}, got {valid_count}")
                
                expected_prefixes = expected_lengths + [0] * (8 - len(expected_lengths))
                
                for j in range(8):
                    if has_signal(dut, f'prefixes_{j}'):
                        prefix_val = int(getattr(dut, f'prefixes_{j}').value)
                    elif has_signal(dut, 'prefixes'):
                        prefix_val = int(dut.prefixes[j].value)
                    else:
                        raise TestFailure("prefixes signal not found")
                    
                    if prefix_val != expected_prefixes[j]:
                        raise TestFailure(f"prefixes[{j}] mismatch: expected {expected_prefixes[j]}, got {prefix_val}")
            
            cocotb.log.info(f"  PASS: {desc}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL (Test {i+1}): {e}")
            failed += 1
    
    # Report final results
    cocotb.log.info(f"\nFinal Results: {passed} passed, {failed} failed out of {len(test_cases)} tests")
    
    if failed:
        raise TestFailure(f"{failed} test(s) failed")
