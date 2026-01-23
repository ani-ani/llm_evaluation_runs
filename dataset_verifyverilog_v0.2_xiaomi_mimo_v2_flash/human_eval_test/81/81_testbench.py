import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

# Fixed-point conversion helpers
def float_to_q16_16(value):
    return int(value * 65536) & 0xFFFFFFFF

# ASCII representations for letter grades (5 characters, 4:0 indices)
GRADE_MAP = {
    'A+': 0x412B2020,  # "A+  "
    'A ': 0x41202020,  # "A   "
    'A-': 0x412D2020,  # "A-  "
    'B+': 0x422B2020,  # "B+  "
    'B ': 0x42202020,  # "B   "
    'B-': 0x422D2020,  # "B-  "
    'C+': 0x432B2020,  # "C+  "
    'C ': 0x43202020,  # "C   "
    'C-': 0x432D2020,  # "C-  "
    'D+': 0x442B2020,  # "D+  "
    'D ': 0x44202020,  # "D   "
    'D-': 0x442D2020,  # "D-  "
    'E ': 0x45202020,  # "E   "
}

def python_grade_conversion(gpa):
    """Python reference implementation"""
    if gpa == 4.0:
        return 'A+'
    elif gpa >= 3.7:
        return 'A'
    elif gpa >= 3.3:
        return 'A-'
    elif gpa >= 3.0:
        return 'B+'
    elif gpa >= 2.7:
        return 'B'
    elif gpa >= 2.3:
        return 'B-'
    elif gpa >= 2.0:
        return 'C+'
    elif gpa >= 1.7:
        return 'C'
    elif gpa >= 1.3:
        return 'C-'
    elif gpa >= 1.0:
        return 'D+'
    elif gpa >= 0.7:
        return 'D'
    elif gpa >= 0.0:
        return 'D-'
    else:
        return 'E'

@cocotb.test()
async def test_grade_converter(dut):
    """Test grade converter with multiple GPA values"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.gpa_fixed.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (gpa_float, expected_grade)
    test_cases = [
        (4.0, 'A+'),
        (3.0, 'B+'),
        (1.7, 'C-'),
        (2.0, 'C+'),
        (3.5, 'A-'),
        (1.2, 'D+'),
        (0.5, 'D-'),
        (0.0, 'E'),
        (1.0, 'D'),
        (0.3, 'D-'),
        (1.5, 'C-'),
        (2.8, 'B'),
        (3.3, 'B+'),
        (0.7, 'D-'),
        (3.7, 'A'),
        (3.35, 'A-'),
        (2.3, 'B-'),
        (2.35, 'B-'),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for gpa_float, expected_grade in test_cases:
        # Convert to fixed-point
        gpa_fixed = float_to_q16_16(gpa_float)
        dut.gpa_fixed.value = gpa_fixed
        
        # Start conversion
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (latency = 3 cycles)
        for _ in range(5):
            await RisingEdge(dut.clk)
            if dut.done.value:
                break
        
        # Read result
        result_raw = int(dut.letter_grade.value)
        
        # Convert to ASCII string
        result_chars = []
        for i in range(5):
            char = (result_raw >> (i * 8)) & 0xFF
            if char != 0x20:  # Skip spaces
                result_chars.append(chr(char))
        result_str = ''.join(result_chars)
        
        # Compare
        if result_str != expected_grade:
            raise TestFailure(
                f"GPA {gpa_float} => Expected '{expected_grade}', got '{result_str}'"
            )
        
        print(f"Test passed: GPA {gpa_float} -> '{result_str}'")
        passed += 1
    
    print(f"
=== Summary: {passed}/{total} tests passed ===")

@cocotb.test()
async def test_grade_converter_edge_cases(dut):
    """Test edge cases for grade converter"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.gpa_fixed.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Edge cases
    edge_cases = [
        (0.0, 'E', 'Exact zero'),
        (0.0001, 'D-', 'Just above zero'),
        (0.6999, 'D-', 'Just below 0.7'),
        (0.7, 'D', 'Exact 0.7'),
        (0.9999, 'D', 'Just below 1.0'),
        (1.0, 'D', 'Exact 1.0'),
        (1.2999, 'D+', 'Just below 1.3'),
        (1.3, 'C-', 'Exact 1.3'),
        (1.6999, 'C-', 'Just below 1.7'),
        (1.7, 'C', 'Exact 1.7'),
        (1.9999, 'C', 'Just below 2.0'),
        (2.0, 'C+', 'Exact 2.0'),
        (2.2999, 'C+', 'Just below 2.3'),
        (2.3, 'B-', 'Exact 2.3'),
        (2.6999, 'B-', 'Just below 2.7'),
        (2.7, 'B', 'Exact 2.7'),
        (2.9999, 'B', 'Just below 3.0'),
        (3.0, 'B+', 'Exact 3.0'),
        (3.2999, 'B+', 'Just below 3.3'),
        (3.3, 'A-', 'Exact 3.3'),
        (3.6999, 'A-', 'Just below 3.7'),
        (3.7, 'A', 'Exact 3.7'),
        (3.9999, 'A', 'Just below 4.0'),
        (4.0, 'A+', 'Exact 4.0'),
    ]
    
    passed = 0
    total = len(edge_cases)
    
    for gpa_float, expected_grade, description in edge_cases:
        gpa_fixed = float_to_q16_16(gpa_float)
        dut.gpa_fixed.value = gpa_fixed
        
        # Start conversion
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        for _ in range(5):
            await RisingEdge(dut.clk)
            if dut.done.value:
                break
        
        # Read result
        result_raw = int(dut.letter_grade.value)
        result_chars = []
        for i in range(5):
            char = (result_raw >> (i * 8)) & 0xFF
            if char != 0x20:
                result_chars.append(chr(char))
        result_str = ''.join(result_chars)
        
        # Compare
        if result_str != expected_grade:
            raise TestFailure(
                f"{description}: GPA {gpa_float} => Expected '{expected_grade}', got '{result_str}'"
            )
        
        print(f"Edge case passed: {description} (GPA {gpa_float}) -> '{result_str}'")
        passed += 1
    
    print(f"
=== Edge Cases Summary: {passed}/{total} tests passed ===")