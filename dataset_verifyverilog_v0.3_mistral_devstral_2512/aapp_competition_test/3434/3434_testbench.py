import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits - 1))), min((1 << (bits - 1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# DP function to compute expected probability for scaled parameters
def compute_probability(our_healths, opp_healths, damage):
    # our_healths and opp_healths are lists of length 2, with values 0-2
    # damage is 0-10
    # Returns probability as float
    # Use memoization
    from functools import lru_cache
    @lru_cache(maxsize=None)
    def dp(our, opp, rem):
        # our and opp are tuples of two healths (sorted descending)
        if rem == 0 or (our[0] == 0 and our[1] == 0 and opp[0] == 0 and opp[1] == 0):
            return 1.0 if (opp[0] == 0 and opp[1] == 0) else 0.0
        # Count living minions
        L = sum(x > 0 for x in our + opp)
        if L == 0:
            return 1.0 if (opp[0] == 0 and opp[1] == 0) else 0.0
        total = 0.0
        inv_L = 1.0 / L
        # Our minions
        for i in range(2):
            if our[i] > 0:
                new_our = list(our)
                new_our[i] -= 1
                if new_our[i] == 0:
                    new_our = [x for x in new_our if x > 0]
                    new_our += [0] * (2 - len(new_our))
                new_our.sort(reverse=True)
                total += inv_L * dp(tuple(new_our), opp, rem - 1)
        # Opp minions
        for i in range(2):
            if opp[i] > 0:
                new_opp = list(opp)
                new_opp[i] -= 1
                if new_opp[i] == 0:
                    new_opp = [x for x in new_opp if x > 0]
                    new_opp += [0] * (2 - len(new_opp))
                new_opp.sort(reverse=True)
                total += inv_L * dp(our, tuple(new_opp), rem - 1)
        return total
    # Sort healths descending
    our_sorted = sorted(our_healths, reverse=True)
    opp_sorted = sorted(opp_healths, reverse=True)
    # Pad to length 2 with zeros
    our_sorted += [0] * (2 - len(our_sorted))
    opp_sorted += [0] * (2 - len(opp_sorted))
    prob = dp(tuple(our_sorted), tuple(opp_sorted), damage)
    return prob

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_explosion_probability(dut):
    """Test the explosion probability module with scaled test cases."""
    
    # Define test cases
    # Test case 1: n=1, m=2, d=2, our=[2], opp=[1,1]
    # In scaled: our_health1=2, our_health2=0, opp_health1=1, opp_health2=1, damage=2
    # Expected probability: 1/3 = 21845 in Q16.16
    test_cases = [
        {
            'our1': 2, 'our2': 0,
            'opp1': 1, 'opp2': 1,
            'damage': 2,
            'expected_float': 1.0/3.0
        },
        {
            'our1': 2, 'our2': 2,
            'opp1': 2, 'opp2': 2,
            'damage': 0,
            'expected_float': 0.0
        }
    ]
    
    for i, tc in enumerate(test_cases):
        # Set inputs
        dut.our_health1.value = tc['our1']
        dut.our_health2.value = tc['our2']
        dut.opp_health1.value = tc['opp1']
        dut.opp_health2.value = tc['opp2']
        dut.damage.value = tc['damage']
        
        # Wait for combinational propagation
        await Timer(10, units='ns')
        
        # Read output
        if not is_value_defined(dut.probability_out.value):
            raise TestFailure(f"Test {i+1}: Output is undefined (X/Z)")
        
        result = int(dut.probability_out.value)
        
        # Compute expected Q16.16 value
        expected_float = tc['expected_float']
        expected_int = int(round(expected_float * 65536))
        
        # Allow small rounding error
        if abs(result - expected_int) > 1:
            raise TestFailure(f"Test {i+1}: Expected {expected_int} (0x{expected_int:08X}), got {result} (0x{result:08X})")
        
        dut._log.info(f"Test {i+1} passed: result = 0x{result:08X} (expected 0x{expected_int:08X})")
    
    dut._log.info("All tests passed!")
