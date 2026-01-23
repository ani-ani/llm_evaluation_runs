import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_hex_key_counter(dut):
    """Test the hex_key_counter module with various hex strings."""
    
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_in.value = 0
    dut.len.value = 0
    
    for _ in range(3):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Helper function to convert hex char to ASCII and check if prime
    def get_char_val(c):
        return ord(c)
    
    def is_prime_hex(c):
        primes = {'2', '3', '5', '7', 'B', 'D'}
        return c in primes
    
    # Test cases: (hex_string, expected_count)
    test_cases = [
        ("AB", 1),
        ("1077E", 2),
        ("ABED1A33", 4),
        ("2020", 2),
        ("123456789ABCDEF0", 6),
        ("112233445566778899AABBCCDDEEFF00", 12),
        ("", 0),
        ("2357BD", 6),  # All prime digits
        ("14689ACEF0", 0)  # No prime digits
    ]
    
    # Pre-generate ASCII values for test strings
    test_data = []
    for s, expected in test_cases:
        ascii_vals = [ord(c) for c in s]
        test_data.append((s, ascii_vals, len(ascii_vals), expected))
    
    passed = 0
    total = len(test_data)
    
    for i, (hex_str, ascii_vals, length, expected) in enumerate(test_data):
        dut._log.info(f"Test {i+1}: Input='{hex_str}' (len={length}), Expected={expected}")
        
        # Setup inputs
        dut.start.value = 1
        dut.len.value = length
        
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Create memory simulation
        current_addr = 0
        
        # Wait for processing (max 20 cycles or until done)
        for cycle in range(20):
            # Provide character data based on address
            if current_addr < length:
                dut.char_in.value = ascii_vals[current_addr]
            else:
                dut.char_in.value = 0
            
            # Update address output
            dut._log.info(f"Cycle {cycle}: addr={int(dut.char_addr.value)}, done={int(dut.done.value if is_value_defined(dut.done.value) else -1)}")
            
            # Check if done
            if is_value_defined(dut.done.value) and dut.done.value == 1:
                if is_value_defined(dut.result.value):
                    result = int(dut.result.value)
                    if result == expected:
                        dut._log.info(f"Test {i+1} PASSED: Got {result}")
                        passed += 1
                    else:
                        raise TestFailure(f"Test {i+1} FAILED: Expected {expected}, Got {result}")
                else:
                    raise TestFailure(f"Test {i+1} FAILED: Result is undefined (X/Z)")
                break
            
            # Read next address from design
            if is_value_defined(dut.char_addr.value):
                next_addr = int(dut.char_addr.value)
                if next_addr != current_addr:
                    current_addr = next_addr
                    dut._log.info(f"  -> Address changed to {current_addr}")
            
            await RisingEdge(dut.clk)
        else:
            # Timeout
            if is_value_defined(dut.result.value):
                result = int(dut.result.value)
                if result == expected:
                    dut._log.info(f"Test {i+1} PASSED (completed after loop): Got {result}")
                    passed += 1
                else:
                    raise TestFailure(f"Test {i+1} FAILED (timeout): Expected {expected}, Got {result}")
            else:
                raise TestFailure(f"Test {i+1} FAILED: Timeout - done not asserted within 20 cycles")
    
    dut._log.info(f"\nSummary: {passed}/{total} tests passed")
    
    if passed != total:
        raise TestFailure(f"Overall failure: {passed}/{total} passed")

@cocotb.test(timeout_time=100, timeout_unit="ms")
async def test_edge_case_empty_string(dut):
    """Test with empty string (length 0)."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    dut.len.value = 0
    dut.char_in.value = 0
    
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    for _ in range(5):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            if is_value_defined(dut.result.value):
                result = int(dut.result.value)
                if result == 0:
                    dut._log.info("Empty string test PASSED")
                    return
            break
    
    raise TestFailure("Empty string test failed - expected 0")

@cocotb.test(timeout_time=100, timeout_unit="ms")
async def test_single_prime_digit(dut):
    """Test individual prime digits."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    primes = ['2', '3', '5', '7', 'B', 'D']
    
    for p in primes:
        dut.start.value = 1
        dut.len.value = 1
        dut.char_in.value = ord(p)
        
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        for _ in range(5):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and dut.done.value == 1:
                if is_value_defined(dut.result.value):
                    result = int(dut.result.value)
                    if result == 1:
                        dut._log.info(f"Single prime '{p}' PASSED")
                        break
                else:
                    raise TestFailure(f"Single prime '{p}' failed: undefined result")
        else:
            raise TestFailure(f"Single prime '{p}' failed: done not asserted")
    
    dut._log.info("All single prime tests PASSED")
