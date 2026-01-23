import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# Helper function to check if value is defined
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_probability(dut):
    """Test probability module for N=2 to 8"""
    
    # Test cases: N to expected fixed-point value
    test_cases = [2, 3, 4, 5, 6, 7, 8]
    expected = {
        2: 0xFFFFFFFF,
        3: 0xFFFFFFFF,
        4: 0xF672B0A6,
        5: 0xEBEDFA58,
        6: 0xE246D38C,
        7: 0xD93A5C66,
        8: 0xD03A5C64
    }
    
    # Test valid N values
    for n in test_cases:
        dut.N.value = n
        await Timer(10, units='ns')  # Allow combinational propagation
        
        if not is_value_defined(dut.prob.value):
            raise TestFailure(f"Output prob is undefined (X/Z) for N={n}")
        
        prob_val = int(dut.prob.value)
        expected_val = expected[n]
        
        if prob_val != expected_val:
            raise TestFailure(
                f"N={n}: expected 0x{expected_val:08X}, got 0x{prob_val:08X}"
            )
        
        dut._log.info(f"N={n}: PASS - prob=0x{prob_val:08X}")
    
    # Test boundary cases: N=1 and N=9 (should output 0)
    for invalid_n in [1, 9]:
        dut.N.value = invalid_n
        await Timer(10, units='ns')
        
        if not is_value_defined(dut.prob.value):
            raise TestFailure(f"Output prob is undefined for N={invalid_n}")
        
        prob_val = int(dut.prob.value)
        if prob_val != 0:
            raise TestFailure(
                f"N={invalid_n}: expected 0, got 0x{prob_val:08X}"
            )
        
        dut._log.info(f"N={invalid_n}: PASS - prob=0x{prob_val:08X}")
    
    dut._log.info("="*50)
    dut._log.info("All tests passed successfully!")