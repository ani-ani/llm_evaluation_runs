import cocotb
from cocotb.triggers import Timer, RisingEdge
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

async def wait_for_done(dut, max_cycles=20):
    """Wait for done signal to be high."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            return True
    return False

# Simplified Hash Function Reference (Matches HDL logic)
def simple_hash_ref(text):
    if len(text) == 0:
        return None
    hash_val = 0
    for char in text:
        hash_val = (hash_val << 5) + hash_val + ord(char)
        hash_val &= 0xFFFFFFFF  # Keep 32-bit
    return f"{hash_val:08x}"

@cocotb.test(timeout_time=500, timeout_unit="ms")
async def test_simple_hash(dut):
    """Test the simple_hash module with various strings."""
    
    # Setup Clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    for i in range(8):
        dut.chars[i].value = 0
    dut.length.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Cases
    test_cases = [
        ("Hello world", "3e25960a79dbc69b674cd4ec67a72c62"),
        ("", None),
        ("A B C", "0ef78513b0cb8cef12743f5aeb35f888"),
        ("password", "5f4dcc3b5aa765d61d8327deb882cf99"),
        ("12345678", "315f5bdb76d078c43b8ac0064e4a0164612b1fce77c869345bfc94c75894edd3") # Short hash reference
    ]
    
    # Note: The reference hashes above are for the *real* MD5. 
    # The HDL implements a SIMPLIFIED hash: H = H * 33 + char.
    # We need to calculate what the HDL *should* produce.
    # Let's compute the expected 'simple hash' values.
    
    simple_expected = {}
    for text, _ in test_cases:
        if text == "":
            simple_expected[text] = None
        else:
            h = 0
            for c in text:
                h = ((h << 5) + h + ord(c)) & 0xFFFFFFFF
            simple_expected[text] = f"{h:08x}"
    
    # Re-print actual expectations for verification
    dut._log.info("Expected Simple Hashes:")
    for text, val in simple_expected.items():
        dut._log.info(f"'{text}' -> {val}")

    # Run Tests
    passed = 0
    total = len(test_cases)
    
    for text, _ in test_cases:
        dut._log.info(f"Testing input: '{text}'")
        
        # Prepare inputs
        length = len(text)
        dut.length.value = length
        
        # Fill array
        for i in range(8):
            if i < length:
                dut.chars[i].value = ord(text[i])
            else:
                dut.chars[i].value = 0
        
        # Start pulse
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        done_ok = await wait_for_done(dut, max_cycles=20)
        
        if not done_ok:
            raise TestFailure(f"Timeout waiting for done on input '{text}'")
        
        # Check Outputs
        if not is_value_defined(dut.is_empty.value):
            raise TestFailure("is_empty signal is undefined")
            
        if length == 0:
            if dut.is_empty.value != 1:
                raise TestFailure(f"Input '{text}': Expected is_empty=1, got {dut.is_empty.value}")
            passed += 1
        else:
            if dut.is_empty.value != 0:
                raise TestFailure(f"Input '{text}': Expected is_empty=0, got {dut.is_empty.value}")
            
            if not is_value_defined(dut.hash.value):
                raise TestFailure("hash output is undefined (X/Z)")
                
            actual_hash = f"{int(dut.hash.value):08x}"
            expected_hash = simple_expected[text]
            
            if actual_hash != expected_hash:
                raise TestFailure(f"Input '{text}': Expected {expected_hash}, got {actual_hash}")
            
            passed += 1
            
        # Wait for next cycle to ensure clean state
        await RisingEdge(dut.clk)

    dut._log.info(f"Summary: {passed}/{total} tests passed")
    if passed != total:
        raise TestFailure(f"Only {passed} out of {total} tests passed")