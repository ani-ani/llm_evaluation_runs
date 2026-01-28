import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
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

async def wait_for_done(dut, max_cycles=100):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_string_array(dut, string_val):
    """Write string data to dut.str_data array."""
    # Pad or truncate to 8 characters
    chars = list(string_val[:8].encode('ascii'))
    while len(chars) < 8:
        chars.append(0)  # Null padding
    
    # Check if array is accessed via sub-signals or direct array
    if has_signal(dut, 'str_data'):
        # Try to write to array elements
        for i in range(8):
            if i < len(chars):
                # Check if it's a bus of 8 bits per element or separate signals
                if hasattr(dut.str_data, '__getitem__'):
                    dut.str_data[i].value = chars[i]
                else:
                    # Check for str_data_0, str_data_1 etc.
                    signal_name = f'str_data_{i}'
                    if has_signal(dut, signal_name):
                        getattr(dut, signal_name).value = chars[i]
                    else:
                        # Fallback: assume dut.str_data is a single wire (unlikely)
                        pass
            else:
                if hasattr(dut.str_data, '__getitem__'):
                    dut.str_data[i].value = 0
    else:
        # If no str_data signal, this is likely a testbench only using str_len
        cocotb.log.warning("str_data not found in DUT, skipping string data write")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_prime_length(dut):
    # Clock setup
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    await reset_dut(dut, cycles=2)
    
    # Test cases: (string, expected_prime_length)
    test_cases = [
        ("Hello", True),        # 5 letters -> prime
        ("abcdcba", True),      # 7 letters -> prime
        ("kittens", True),      # 7 letters -> prime
        ("orange", False),      # 6 letters -> not prime
        ("wow", True),          # 3 letters -> prime
        ("world", True),        # 5 letters -> prime
        ("MadaM", True),        # 5 letters -> prime
        ("Wow", True),          # 3 letters -> prime
        ("", False),            # 0 letters -> not prime
        ("HI", True),           # 2 letters -> prime
        ("go", True),           # 2 letters -> prime
        ("gogo", False),        # 4 letters -> not prime
        ("aaaaaaaaaaaaaaa", False), # 15 letters -> truncated to 8 -> not prime (8)
        ("Madam", True),        # 5 letters -> prime
        ("M", False),           # 1 letter -> not prime
        ("0", False),           # 1 letter -> not prime
    ]
    
    passed = 0
    failed = 0
    
    for i, (string_val, expected) in enumerate(test_cases):
        # Compute expected primality based on length (0-8)
        length = min(len(string_val), 8)  # Hardware truncates at 8
        
        # Prime check for 0-8 range
        is_prime = 0
        primes = [2, 3, 5, 7]
        if length in primes:
            is_prime = 1
        
        expected_result = is_prime
        
        cocotb.log.info(f"Test {i+1}: String='{string_val}' (len={length}) -> Expected: {expected_result}")
        
        try:
            # Write string length
            dut.str_len.value = clamp_to_width(length, 4)
            
            # Write string data (optional for this problem, but good practice)
            await write_string_array(dut, string_val)
            
            # Start pulse
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut, max_cycles=100)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            
            if result != expected_result:
                raise TestFailure(f"Expected {expected_result}, got {result} for length {length}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
        
        # Reset for next test
        await RisingEdge(dut.clk)
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    else:
        cocotb.log.info(f"All {len(test_cases)} tests passed!")
