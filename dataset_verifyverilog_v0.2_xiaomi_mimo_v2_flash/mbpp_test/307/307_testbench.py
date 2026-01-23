import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock

@cocotb.test()
async def test_colon_tuplex(dut):
    """Test colon_tuplex module with multiple test cases"""
    
    # Initialize clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.m.value = 0
    dut.n.value = 0
    dut.tuplex_0.value = ord('H')  # 0x48
    dut.tuplex_1.value = 5
    dut.tuplex_2.value = 0  # empty list placeholder
    dut.tuplex_3.value = 1  # True
    
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        # (tuplex, m, n, expected_result)
        # Test 1: m=2, n=50
        ([ord('H'), 5, 0, 1], 2, 50, [ord('H'), 5, 50, 1]),
        # Test 2: m=2, n=100  
        ([ord('H'), 5, 0, 1], 2, 100, [ord('H'), 5, 100, 1]),
        # Test 3: m=2, n=500 (500 fits in 8 bits)
        ([ord('H'), 5, 0, 1], 2, 244, [ord('H'), 5, 244, 1]),  # 500 % 256 = 244
        # Edge case: m=0
        ([ord('H'), 5, 0, 1], 0, 99, [99, 5, 0, 1]),
        # Edge case: m=3
        ([ord('H'), 5, 0, 1], 3, 255, [ord('H'), 5, 0, 255]),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (tuplex, m, n, expected) in enumerate(test_cases):
        print(f"
Test {i+1}: tuplex={tuplex}, m={m}, n={n}")
        
        # Set inputs
        dut.tuplex_0.value = tuplex[0]
        dut.tuplex_1.value = tuplex[1]
        dut.tuplex_2.value = tuplex[2]
        dut.tuplex_3.value = tuplex[3]
        dut.m.value = m
        dut.n.value = n
        dut.start.value = 1
        
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for processing (2 cycles)
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        
        # Check done signal
        assert dut.done.value == 1, f"Done signal not high after 2 cycles"
        
        # Read results
        result = [
            int(dut.result_0.value),
            int(dut.result_1.value),
            int(dut.result_2.value),
            int(dut.result_3.value)
        ]
        
        print(f"  Expected: {expected}")
        print(f"  Got:      {result}")
        
        # Verify
        if result == expected:
            passed += 1
            print(f"  ✓ PASSED")
        else:
            print(f"  ✗ FAILED")
        
        assert result == expected, f"Test {i+1} failed: expected {expected}, got {result}"
        
        # Reset for next test
        dut.rst_n.value = 0
        await Timer(5, units='ns')
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    print(f"
=== Summary: {passed}/{total} tests passed ===")
