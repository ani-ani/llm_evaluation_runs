import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try:
        int(v); return True
    except:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except:
        return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

@cocotb.test(timeout_time=1000, timeout_unit='ms')
async def test_wolves_sheep_cabbage(dut):
    # Test cases scaled to 8-bit (0-255)
    test_cases = [
        # (W, S, C, K, expected_result, description)
        (1, 1, 1, 1, 0, "All three with K=1 - impossible"),
        (1, 1, 1, 2, 1, "All three with K=2 - possible"),
        (2, 2, 0, 1, 0, "Wolves+Sheep, K=1 - conflict"),
        (1, 1, 1, 2, 1, "Standard case"),
        (10, 11, 12, 10, 0, "Many items, insufficient capacity"),
        (10, 11, 12, 11, 1, "Many items, sufficient for K>=2"),
        (0, 0, 5, 3, 1, "Only cabbages"),
        (5, 0, 0, 2, 1, "Only wolves"),
        (0, 5, 0, 1, 1, "Only sheep"),
        (1, 0, 1, 1, 1, "Wolves+cabbages, no sheep"),
        (0, 1, 1, 1, 1, "Sheep+cabbages, no wolves"),
        (1, 1, 0, 1, 1, "Wolves+sheep, no cabbages"),
        (255, 255, 255, 255, 1, "Max values"),
        (0, 0, 0, 0, 0, "All zero, K=0"),
        (1, 0, 0, 0, 0, "Single item, K=0"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (W, S, C, K, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Clamp values to 8-bit
            W = clamp_to_width(W, 8)
            S = clamp_to_width(S, 8)
            C = clamp_to_width(C, 8)
            K = clamp_to_width(K, 8)
            
            # Set inputs
            dut.W.value = W
            dut.S.value = S
            dut.C.value = C
            dut.K.value = K
            
            # Wait a bit for combinatorial logic
            await Timer(10, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result}")
            
            # Also check done signal
            if is_value_defined(dut.done.value):
                done_val = int(dut.done.value)
                if done_val != 1:
                    raise TestFailure(f"Done signal should be 1, got {done_val}")
            
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
        except Exception as e:
            cocotb.log.error(f"ERROR: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed+failed}")
