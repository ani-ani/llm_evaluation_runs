import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# ============================================================================
# MANDATORY HELPER FUNCTIONS
# ============================================================================
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

# ============================================================================
# MAIN TEST
# ============================================================================
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_stone_game(dut):
    """Test the StoneGame module with various test cases"""
    
    # Initialize inputs
    dut.n.value = 0
    for i in range(8):
        getattr(dut, f'a{i}').value = 0
    
    # Small delay for initialization
    await Timer(10, units='ns')
    
    # Define test cases: (n, stones_list, expected_win)
    test_cases = [
        (1, [0], 0),
        (2, [1,0], 0),
        (2, [2,2], 1),
        (3, [2,3,1], 1),
        (3, [3,3,3], 0),
        (3, [4,4,4], 0),
        (4, [2,2,4,4], 0),
        (5, [2,2,4,4,7], 0),
        (3, [0,0,5], 0),
        (3, [0,0,6], 0),
        (3, [3,4,4], 0),
        (3, [4,5,5], 0),
        (5, [0,5,6,7,8], 0),
        (5, [0,5,6,7,9], 1),
        (5, [0,0,1,5,8], 0),
        (5, [0,0,1,5,9], 0),
        (5, [0,0,0,999,555], 0),
        (10, [0]*10, 0),
        (1, [1], 1),
        (1, [2], 0),
        (1, [3], 1),
        (1, [4], 0),
        (7, [1000000000]*2 + [5,8,7,3,999999999], 0),
        (2, [0,0], 0),
        (2, [0,1], 0),
        (2, [0,2], 0),
        (2, [1,1], 1),
        (2, [1,2], 1),
        (2, [3,3], 1),
        (3, [0,1,1], 0),
        (3, [0,1,3], 0),
        (3, [1,2,2], 0),
        (3, [1,1,2], 0),
        (3, [1,1,6], 0),
        (4, [0,1,1,2], 0),
        (4, [1,2,2,10000], 0),
        (5, [0,1,3,3,4], 0),
        (5, [0,1,8,9,9], 1),
        (10, [1,5,8,13,50,150,151,151,200,255], 0),
        (5, [5,5,5,5,5], 0)
    ]
    
    passed = 0
    failed = 0
    
    for n_val, stones, expected_win in test_cases:
        cocotb.log.info(f"Testing n={n_val}, stones={stones}, expected={'sjfnb' if expected_win else 'cslnb'}")
        
        # Set n
        dut.n.value = n_val
        
        # Set stone values (only first n_val matter)
        arr = stones + [0] * (8 - len(stones))
        for i in range(8):
            getattr(dut, f'a{i}').value = arr[i]
        
        # Wait for combinational logic
        await Timer(10, units='ns')
        
        # Read result
        if not is_value_defined(dut.win.value):
            cocotb.log.error(f"  FAIL: win signal undefined")
            failed += 1
            continue
            
        win_val = int(dut.win.value)
        
        # Check
        if win_val != expected_win:
            cocotb.log.error(f"  FAIL: Expected {'sjfnb' if expected_win else 'cslnb'}, got {'sjfnb' if win_val else 'cslnb'}")
            failed += 1
        else:
            cocotb.log.info(f"  PASS: Result {'sjfnb' if win_val else 'cslnb'}")
            passed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")