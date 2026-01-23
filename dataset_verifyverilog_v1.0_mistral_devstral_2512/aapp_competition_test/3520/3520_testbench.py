import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure
import math

# Helper functions
def is_value_defined(value):
    try:
        float(value)
        return True
    except ValueError:
        return False

def safe_float(value, default=0.0):
    try:
        return float(value)
    except ValueError:
        return default

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_lifespan_max(dut):
    """Test the lifespan calculator with multiple test cases"""
    
    # Test cases
    test_cases = [
        {
            'n': 100, 'c': 10, 'p': 3,
            'pills': [
                (15, 99, 98),
                (40, 3, 2),
                (90, 10, 9)
            ],
            'expected': 115.0
        },
        {
            'n': 10000, 'c': 100, 'p': 4,
            'pills': [
                (1000, 1001, 1000),
                (1994, 10, 9),
                (2994, 100, 89),
                (3300, 1000, 1)
            ],
            'expected': 6633900.0
        }
    ]
    
    for test_idx, test in enumerate(test_cases):
        dut._log.info(f"Running test case {test_idx + 1}")
        
        # Set inputs
        dut.n.value = test['n']
        dut.c.value = test['c']
        dut.p.value = test['p']
        
        # Set pills - pad to 8 pills with zeros
        pill_values = [0] * 8
        for i, (t, x, y) in enumerate(test['pills']):
            pill_values[i] = (t << 64) | (x << 32) | y
        
        # Assign individual pill inputs
        dut.t_0.value = test['pills'][0][0] if len(test['pills']) > 0 else 0
        dut.x_0.value = test['pills'][0][1] if len(test['pills']) > 0 else 0
        dut.y_0.value = test['pills'][0][2] if len(test['pills']) > 0 else 0
        
        dut.t_1.value = test['pills'][1][0] if len(test['pills']) > 1 else 0
        dut.x_1.value = test['pills'][1][1] if len(test['pills']) > 1 else 0
        dut.y_1.value = test['pills'][1][2] if len(test['pills']) > 1 else 0
        
        dut.t_2.value = test['pills'][2][0] if len(test['pills']) > 2 else 0
        dut.x_2.value = test['pills'][2][1] if len(test['pills']) > 2 else 0
        dut.y_2.value = test['pills'][2][2] if len(test['pills']) > 2 else 0
        
        dut.t_3.value = test['pills'][3][0] if len(test['pills']) > 3 else 0
        dut.x_3.value = test['pills'][3][1] if len(test['pills']) > 3 else 0
        dut.y_3.value = test['pills'][3][2] if len(test['pills']) > 3 else 0
        
        dut.t_4.value = test['pills'][4][0] if len(test['pills']) > 4 else 0
        dut.x_4.value = test['pills'][4][1] if len(test['pills']) > 4 else 0
        dut.y_4.value = test['pills'][4][2] if len(test['pills']) > 4 else 0
        
        dut.t_5.value = test['pills'][5][0] if len(test['pills']) > 5 else 0
        dut.x_5.value = test['pills'][5][1] if len(test['pills']) > 5 else 0
        dut.y_5.value = test['pills'][5][2] if len(test['pills']) > 5 else 0
        
        dut.t_6.value = test['pills'][6][0] if len(test['pills']) > 6 else 0
        dut.x_6.value = test['pills'][6][1] if len(test['pills']) > 6 else 0
        dut.y_6.value = test['pills'][6][2] if len(test['pills']) > 6 else 0
        
        dut.t_7.value = test['pills'][7][0] if len(test['pills']) > 7 else 0
        dut.x_7.value = test['pills'][7][1] if len(test['pills']) > 7 else 0
        dut.y_7.value = test['pills'][7][2] if len(test['pills']) > 7 else 0
        
        # Wait for combinational logic to settle
        await Timer(100, units='ns')
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {test_idx + 1}: Result is undefined (X/Z)")
        
        result = safe_float(dut.result.value)
        expected = test['expected']
        
        # Check with tolerance
        tolerance = 1e-6
        if abs(result - expected) > tolerance:
            raise TestFailure(f"Test {test_idx + 1}: Expected {expected}, got {result}")
        
        dut._log.info(f"  PASS: result = {result}")
    
    dut._log.info(f"{'='*50}")
    dut._log.info(f"All {len(test_cases)} tests passed!")