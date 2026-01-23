import cocotb
from cocotb.triggers import Timer
import random

# Convert decimal to Q16.16 fixed-point representation
def to_q16_16(value):
    return int(value * 65536) & 0xFFFFFFFF

# Convert Q16.16 back to decimal for verification
def from_q16_16(value):
    # Sign extension for negative numbers
    if value & 0x80000000:
        value = value - 0x100000000
    return value / 65536.0

@cocotb.test()
async def test_triangle_area(dut):
    """Test triangle_area module with various inputs"""
    
    test_cases = [
        (5, 3),      # Original: 5 * 3 / 2 = 7.5
        (2, 2),      # Original: 2 * 2 / 2 = 2.0
        (10, 8),     # Original: 10 * 8 / 2 = 40.0
        (1, 1),      # Edge case: 1 * 1 / 2 = 0.5
        (15.5, 2.5), # Decimal: 15.5 * 2.5 / 2 = 19.375
    ]
    
    passed = 0
    total = len(test_cases)
    
    for a_val, h_val in test_cases:
        # Convert to Q16.16
        a_fixed = to_q16_16(a_val)
        h_fixed = to_q16_16(h_val)
        
        # Expected result (as integer in Q16.16)
        expected = to_q16_16(a_val * h_val / 2)
        
        # Apply inputs
        dut.a.value = a_fixed
        dut.h.value = h_fixed
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Read output
        result = dut.area.value.integer
        
        # Allow small rounding error (±1 in LSB)
        if abs(result - expected) <= 1:
            passed += 1
            print(f"✓ Test ({a_val}, {h_val}): Expected {expected}, Got {result} (Δ={result-expected})")
        else:
            print(f"✗ Test ({a_val}, {h_val}): Expected {expected}, Got {result}")
            
    print(f"
Result: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"
