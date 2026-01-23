import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_swap_generator(dut):
    """Test swap generator for various n values"""
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (n, expected_valid, expected_count)
    test_cases = [
        (1, True, 0),      # 1 element, no swaps needed
        (3, False, 0),     # Invalid
        (4, True, 6),      # 6 swaps
        (5, True, 10),     # 10 swaps
        (8, True, 28),     # 28 swaps
    ]
    
    total_tests = len(test_cases)
    passed = 0
    
    for n, exp_valid, exp_count in test_cases:
        dut.n.value = n
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for valid/done signals
        swaps = []
        while True:
            await RisingEdge(dut.clk)
            if int(dut.out_valid.value) == 1:
                a = int(dut.a_out.value)
                b = int(dut.b_out.value)
                if a < b:
                    swaps.append((a, b))
                else:
                    swaps.append((b, a))
            if int(dut.done.value) == 1:
                break
        
        # Check valid bit
        if int(dut.valid.value) != (1 if exp_valid else 0):
            print(f"Test n={n}: Expected valid={exp_valid}, got {int(dut.valid.value)}")
            continue
        
        if exp_valid:
            # Check count
            if len(swaps) != exp_count:
                print(f"Test n={n}: Expected {exp_count} swaps, got {len(swaps)}")
                continue
            
            # Check uniqueness
            unique_swaps = set(swaps)
            if len(unique_swaps) != len(swaps):
                print(f"Test n={n}: Duplicate swaps detected")
                continue
            
            # Check completeness (all pairs present)
            expected_pairs = set()
            for i in range(n):
                for j in range(i+1, n):
                    expected_pairs.add((i, j))
            
            if unique_swaps == expected_pairs:
                passed += 1
                print(f"Test n={n}: PASSED")
            else:
                missing = expected_pairs - unique_swaps
                extra = unique_swaps - expected_pairs
                print(f"Test n={n}: FAILED. Missing: {missing}, Extra: {extra}")
        else:
            # For invalid, just check valid bit (done should be high quickly)
            passed += 1
            print(f"Test n={n}: PASSED")
    
    print(f"
Summary: {passed}/{total_tests} tests passed")
    if passed != total_tests:
        raise TestFailure(f"Only {passed} tests passed")