import cocotb
from cocotb.triggers import Timer
import math

def float_to_q16_16(x):
    """Convert float to Q16.16 representation"""
    return int(x * 65536) & 0xFFFFFFFF

def q16_16_to_float(q):
    """Convert Q16.16 to float"""
    if q & 0x80000000:  # negative
        return -((~q + 1) / 65536.0)
    return q / 65536.0

@cocotb.test()
async def test_pickle_packing(dut):
    """Test pickle packing module with various inputs"""
    
    # Test cases: (s, r, n, z, expected_output)
    test_cases = [
        (3.0, 1.0, 4, 40, 3),  # Sample 1: area limit 40%
        (3.0, 1.0, 4, 100, 4),  # Sample 2: no area limit
        (5.0, 1.0, 7, 50, 3),   # Smaller area limit
        (10.0, 1.0, 7, 100, 7), # Large sandwich, all fit
        (2.5, 0.5, 7, 100, 7),  # Smaller sandwich, smaller pickles
        (3.0, 1.0, 0, 100, 0),  # Edge case: no pickles available
        (1.0, 1.0, 7, 100, 1),  # Sandwich = pickle size
        (2.5, 1.0, 7, 100, 3),  # Packing limit
        (3.0, 1.0, 7, 30, 2),   # Very strict area limit
        (4.0, 1.0, 7, 100, 4),  # Can fit 4
        (5.0, 1.0, 7, 100, 6),  # Can fit 6
    ]
    
    passed = 0
    total = len(test_cases)
    
    print("
=== Pickle Packing Tests ===")
    print(f"{'Test':<6} {'S':<6} {'R':<6} {'N':<3} {'Z':<3} {'Exp':<4} {'Got':<4} {'Result'}")
    print("-" * 55)
    
    for i, (s, r, n, z, expected) in enumerate(test_cases):
        # Convert to Q16.16
        s_q = float_to_q16_16(s)
        r_q = float_to_q16_16(r)
        n_q = n & 0x7F  # 7 bits
        z_q = z & 0x7F  # 7 bits
        
        # Apply inputs
        dut.s_ridge.value = s_q
        dut.r_ridge.value = r_q
        dut.n_available.value = n_q
        dut.z_percent.value = z_q
        
        # Wait for combinational logic
        await Timer(10, units='ns')
        
        # Read result
        result = int(dut.max_pickles.value)
        
        # Verify
        test_pass = (result == expected)
        passed += 1 if test_pass else 0
        
        status = "PASS" if test_pass else "FAIL"
        print(f"{i:<6} {s:<6.2f} {r:<6.2f} {n:<3} {z:<3} {expected:<4} {result:<4} {status}")
        
        if not test_pass:
            # Print calculation details for debugging
            area_sandwich = math.pi * s * s
            area_pickle = math.pi * r * r
            max_by_area = int((z/100.0) * area_sandwich / area_pickle)
            print(f"  Area: sandwich={area_sandwich:.2f}, pickle={area_pickle:.2f}, max_by_area={max_by_area}")
            # Packing limits
            k1 = 1 if 2*r <= s else 0
            k2 = 2 if 2*r <= s else 0
            k3 = 3 if r*(1+2/math.sqrt(3)) <= s else 0
            k4 = 4 if r*(1+math.sqrt(2)) <= s else 0
            k5 = 5 if r*2.701 <= s else 0
            k6 = 6 if 3*r <= s else 0
            k7 = 7 if 3*r <= s else 0
            print(f"  Packing: k1={k1}, k2={k2}, k3={k3}, k4={k4}, k5={k5}, k6={k6}, k7={k7}")
    
    print("-" * 55)
    print(f"
{passed}/{total} tests passed")
    assert passed == total, f"Expected all tests to pass, got {passed}/{total}"
