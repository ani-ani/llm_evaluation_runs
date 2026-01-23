import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def to_q1616(value):
    """Convert decimal value to Q16.16 representation."""
    return int(value * 65536)

def from_q1616(value):
    """Convert Q16.16 representation to decimal."""
    if value >= 0x80000000:  # Negative in 32-bit signed
        value = value - 0x100000000
    return value / 65536.0

def encode_operator(op_char):
    """Encode operator character to integer."""
    mapping = {'+': 0, '-': 1, '*': 2, '//': 3, '**': 4}
    return mapping[op_char]

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_algebra_eval(dut):
    """Test algebraic expression evaluation with operator precedence."""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (operators, operands, expected_result)
    test_cases = [
        # Test case 1: ['**', '*', '+'], [2, 3, 4, 5] => 2 + 3 * 4 - 5 = 37
        # Actually: 2 ** 3 * 4 + 5 = 8 * 4 + 5 = 32 + 5 = 37
        ([4, 2, 0], [2, 3, 4, 5], 37.0),
        
        # Test case 2: ['+', '*', '-'], [2, 3, 4, 5] => 2 + 3 * 4 - 5 = 9
        ([0, 2, 1], [2, 3, 4, 5], 9.0),
        
        # Test case 3: ['//', '*'], [7, 3, 4] => 7 // 3 * 4 = 2 * 4 = 8
        ([3, 2], [7, 3, 4], 8.0),
        
        # Additional test case 4: Simple addition ['+'], [10, 20] => 30
        ([0], [10, 20], 30.0),
        
        # Additional test case 5: Mixed precedence ['*', '-'], [5, 2, 3] => 5 * 2 - 3 = 7
        ([2, 1], [5, 2, 3], 7.0),
        
        # Additional test case 6: Exponentiation only ['**'], [2, 5] => 2**5 = 32
        ([4], [2, 5], 32.0),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (ops_list, operands_list, expected) in enumerate(test_cases):
        dut._log.info(f"Test case {i+1}: operators={ops_list}, operands={operands_list}")
        
        # Set number of operators
        dut.num_operators.value = len(ops_list)
        
        # Set operators array (8 elements, fill unused with 0)
        for j in range(8):
            if j < len(ops_list):
                dut.operator[j].value = ops_list[j]
            else:
                dut.operator[j].value = 0
        
        # Set operands array (9 elements, fill unused with 0)
        for j in range(9):
            if j < len(operands_list):
                dut.operand[j].value = to_q1616(operands_list[j])
            else:
                dut.operand[j].value = 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal with cycle timeout
        done_found = False
        for cycle in range(100):  # Max 100 cycles
            await RisingEdge(dut.clk)
            
            if not is_value_defined(dut.done.value):
                continue
            
            if dut.done.value == 1:
                done_found = True
                break
        
        if not done_found:
            raise TestFailure(f"Test {i+1}: Done signal not asserted within 100 cycles")
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {i+1}: Result has undefined value (X/Z)")
        
        result_q1616 = int(dut.result.value)
        result_float = from_q1616(result_q1616)
        
        # Compare with expected (allow small floating point error)
        if abs(result_float - expected) > 0.01:
            raise TestFailure(f"Test {i+1}: expected {expected}, got {result_float} (Q16.16: 0x{result_q1616:08X})")
        
        dut._log.info(f"  Result: {result_float} (expected {expected}) [PASS]")
        passed += 1
        
        # Small delay between tests
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
    
    dut._log.info(f"\n=== SUMMARY: {passed}/{total} tests passed ===")
    
    if passed != total:
        raise TestFailure(f"Only {passed} out of {total} tests passed")