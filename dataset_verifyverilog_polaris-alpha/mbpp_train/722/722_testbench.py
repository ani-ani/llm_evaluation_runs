import cocotb
from cocotb.triggers import Timer
from cocotb.types import LogicArray

# Q4.4 Fixed-point helper
def to_fixed(val):
    return int(val * 16) & 0xFF

test_cases = [
    # Test 1 (Original Test 1 converted)
    {'inputs': {
        # Student heights: 6.2, 5.9, 6.0, 5.8 → 6.2=0x62 (01100010)
        # Student weights: 70 → 4.375 out of range → need scaling adjustment
        # (original weights exceed Q4.4) → use direct integer comparison
        'student0_height': to_fixed(6.2), 'student0_weight': 70,
        'student1_height': to_fixed(5.9), 'student1_weight': 65,
        'student2_height': to_fixed(6.0), 'student2_weight': 68,
        'student3_height': to_fixed(5.8), 'student3_weight': 66,
        'min_height': to_fixed(6.0), 'min_weight': 70,  
    }, 'expected': 0b0001},  # Only student0 passes
    
    # Test 2 (Original Test 2 converted)
    {'inputs': {
        'student0_height': to_fixed(6.2), 'student0_weight': 70,
        'student1_height': to_fixed(5.9), 'student1_weight': 65,
        'student2_height': to_fixed(6.0), 'student2_weight': 68,
        'student3_height': to_fixed(5.8), 'student3_weight': 66,
        'min_height': to_fixed(5.9), 'min_weight': 67,  
    }, 'expected': 0b0101},  # student0 and student2
    
    # Test 3 (Original Test 3 with reduced thresholds)
    {'inputs': {
        'student0_height': to_fixed(6.2), 'student0_weight': 70,
        'student1_height': to_fixed(5.9), 'student1_weight': 65,
        'student2_height': to_fixed(6.0), 'student2_weight': 68,
        'student3_height': to_fixed(5.8), 'student3_weight': 66,
        'min_height': to_fixed(5.7), 'min_weight': 64,  
    }, 'expected': 0b1111},  # All pass
    
    # Edge case: min too high
    {'inputs': {
        'student0_height': to_fixed(6.2), 'student0_weight': 70,
        'student1_height': to_fixed(5.9), 'student1_weight': 65,
        'student2_height': to_fixed(6.0), 'student2_weight': 68,
        'student3_height': to_fixed(5.8), 'student3_weight': 66,
        'min_height': to_fixed(7.0), 'min_weight': 80,  
    }, 'expected': 0b0000},
]

@cocotb.test()
async def test_student_filter(dut):
    passed = 0
    for i, test_case in enumerate(test_cases):
        # Apply inputs
        for sig, val in test_case['inputs'].items():
            getattr(dut, sig).value = val
        await Timer(1, units='ns')
        
        # Get result as integer
        result = dut.passed_students.value.integer
        expected = test_case['expected']
        
        # Check result
        if result == expected:
            passed += 1
            dut._log.info(f"TEST {i} PASSED")
        else:
            dut._log.error(f"TEST {i} FAILED: Got {bin(result)}, expected {bin(expected)}")
    
    total = len(test_cases)
    dut._log.info(f"SUMMARY: {passed}/{total} tests passed")
    assert passed == total