import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer

@cocotb.test()
async def test_oven_decision(dut):
    """Test the oven decision logic for various inputs"""
    
    # Test cases: (n, t, k, d, expected_output)
    # Expected: 1 if YES (build oven), 0 if NO
    test_cases = [
        (8, 6, 4, 5, 1),   # Example 1: YES
        (8, 6, 4, 6, 0),   # Example 2: NO
        (10, 3, 11, 4, 0), # Example 3: NO
        (4, 2, 1, 4, 1),   # Example 4: YES
        (1, 1, 1, 1, 0),   # Edge: n=1, t=1, d=1 -> single_time=1, d+t=2. 1<=2 -> NO
        (3, 1, 1, 1, 1),   # Edge: n=3, t=1, d=1 -> single_time=3, d+t=2. 3>2 -> YES
    ]

    passed = 0
    total = len(test_cases)

    for n, t, k, d, expected in test_cases:
        # Assign inputs
        dut.n.value = n
        dut.t.value = t
        dut.k.value = k
        dut.d.value = d
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Read output
        result = int(dut.build_second.value)
        
        # Assert
        assert result == expected, f"Failed for n={n}, t={t}, k={k}, d={d}: expected {expected}, got {result}"
        if result == expected:
            passed += 1
            dut._log.info(f"Test passed: n={n}, t={t}, k={k}, d={d} -> {result}")
        else:
            dut._log.error(f"Test failed: n={n}, t={t}, k={k}, d={d} -> {result} (expected {expected})")

    dut._log.info(f"Summary: {passed}/{total} tests passed")
