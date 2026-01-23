import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

# Precomputed factorials for n=0 to 20
FACTORIALS = {
    0: 1,
    1: 1,
    2: 2,
    3: 6,
    4: 24,
    5: 120,
    6: 720,
    7: 5040,
    8: 40320,
    9: 362880,
    10: 3628800,
    11: 39916800,
    12: 479001600,
    13: 6227020800,
    14: 87178291200,
    15: 1307674368000,
    16: 20922789888000,
    17: 355687428096000,
    18: 6402373705728000,
    19: 121645100408832000,
    20: 2432902008176640000
}

@cocotb.test()
async def test_factorial_inverse(dut):
    """Test inverse factorial calculation for various inputs"""
    
    # Create and start clock (10ns period)
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.target_factorial.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        (120, 5),           # 5! = 120
        (720, 6),           # 6! = 720
        (5040, 7),          # 7! = 5040
        (40320, 8),         # 8! = 40320
        (362880, 9),        # 9! = 362880
        (3628800, 10),      # 10! = 3628800
        (39916800, 11),     # 11! = 39916800
        (479001600, 12),    # 12! = 479001600
        (1, 0),             # 0! = 1
        (2, 2),             # 2! = 2
        (2432902008176640000, 20),  # 20! = 2432902008176640000
        (999999, 0),        # Not a factorial
        (100, 0),           # Not a factorial
    ]
    
    passed = 0
    total = len(test_cases)
    
    for target, expected_n in test_cases:
        print(f"Testing: target={target}, expected_n={expected_n}")
        
        # Load target value
        dut.target_factorial.value = target
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal (max 22 cycles)
        timeout = 25
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.valid.value == 1:
                break
        
        # Check results
        if dut.valid.value == 1:
            actual_n = int(dut.result_n.value)
            found = int(dut.found.value)
            
            # Verify
            if expected_n == 0:
                # Should not find or find n=0
                if found == 0 or (found == 1 and actual_n == 0):
                    print(f"  PASS: Not found (as expected for non-factorial {target})")
                    passed += 1
                else:
                    print(f"  FAIL: Found n={actual_n} for non-factorial {target}")
            else:
                if found == 1 and actual_n == expected_n:
                    print(f"  PASS: Found n={actual_n}")
                    passed += 1
                else:
                    print(f"  FAIL: Expected n={expected_n}, got n={actual_n}, found={found}")
        else:
            print(f"  FAIL: Valid signal not asserted within timeout")
    
    print(f"
=== Summary: {passed}/{total} tests passed ===")
    assert passed == total, f"Only {passed} out of {total} tests passed"
