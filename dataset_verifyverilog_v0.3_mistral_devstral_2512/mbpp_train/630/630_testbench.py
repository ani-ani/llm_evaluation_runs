import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 8
NUM_OUTPUTS = 9

# Helper functions
def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    """Safely convert cocotb value to int, returning default if X/Z."""
    try:
        return int(value)
    except ValueError:
        return default

# Test function
@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_adjacent_coordinates(dut):
    """Test adjacent coordinate generation."""
    
    # Wait for combinational logic to settle
    await Timer(10, units='ns')
    
    # Test cases: (in_x, in_y, expected list of (x,y) tuples)
    test_cases = [
        (
            3, 4,
            [(2,3), (2,4), (2,5), (3,3), (3,4), (3,5), (4,3), (4,4), (4,5)],
            "Input (3,4)"
        ),
        (
            4, 5,
            [(3,4), (3,5), (3,6), (4,4), (4,5), (4,6), (5,4), (5,5), (5,6)],
            "Input (4,5)"
        ),
        (
            5, 6,
            [(4,5), (4,6), (4,7), (5,5), (5,6), (5,7), (6,5), (6,6), (6,7)],
            "Input (5,6)"
        ),
    ]
    
    passed = 0
    failed = 0
    
    for test_in_x, test_in_y, expected, description in test_cases:
        cocotb.log.info(f"\nTest: {description}")
        cocotb.log.info(f"  Input: ({test_in_x}, {test_in_y})")
        
        try:
            # Set inputs
            dut.in_x.value = test_in_x
            dut.in_y.value = test_in_y
            
            # Wait for propagation
            await Timer(10, units='ns')
            
            # Check all 9 outputs
            all_valid = True
            for i in range(NUM_OUTPUTS):
                # Check valid signal
                if has_signal(dut, f'valid_{i}'):
                    valid_sig = getattr(dut, f'valid_{i}')
                else:
                    valid_sig = dut.valid[i]
                
                if not is_value_defined(valid_sig.value):
                    raise TestFailure(f"Output {i}: valid is undefined")
                
                valid = int(valid_sig.value)
                if valid != 1:
                    raise TestFailure(f"Output {i}: valid should be 1, got {valid}")
                
                # Check coordinates
                if has_signal(dut, f'out_x_{i}'):
                    out_x_sig = getattr(dut, f'out_x_{i}')
                    out_y_sig = getattr(dut, f'out_y_{i}')
                else:
                    out_x_sig = dut.out_x[i]
                    out_y_sig = dut.out_y[i]
                
                if not is_value_defined(out_x_sig.value) or not is_value_defined(out_y_sig.value):
                    raise TestFailure(f"Output {i}: coordinates are undefined")
                
                out_x = int(out_x_sig.value)
                out_y = int(out_y_sig.value)
                
                exp_x, exp_y = expected[i]
                
                if out_x != exp_x or out_y != exp_y:
                    raise TestFailure(
                        f"Output {i}: expected ({exp_x},{exp_y}), got ({out_x},{out_y})"
                    )
                
                cocotb.log.info(f"  Output {i}: ({out_x},{out_y}) [OK]")
            
            cocotb.log.info(f"  PASS")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")

# Helper for signal detection
def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False