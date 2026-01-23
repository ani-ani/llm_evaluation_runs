import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_pythagorean_triple_counter(dut):
    """Test Pythagorean triple counter for various n values"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (n, expected_count)
    test_cases = [
        (2, 0),   # n=2: a,b,c can only be 1, check (1,1,1): 1+1=2≡0, 1≡1? 2%2=0, 1%2=1 -> no
        (3, 0),   # n=3: verify
        (7, 18),  # given example
        (15, 64), # given example
        (4, 6),   # additional test
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n, expected in test_cases:
        # Set n
        dut.n.value = n
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (max 4096 cycles for n=16)
        timeout = 5000
        for _ in range(timeout):
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)
        else:
            raise TestFailure(f"Timeout waiting for done for n={n}")
        
        # Read result
        result = int(dut.count.value)
        
        if result == expected:
            print(f"n={n}: Expected {expected}, Got {result} ✓")
            passed += 1
        else:
            print(f"n={n}: Expected {expected}, Got {result} ✗")
            
        await RisingEdge(dut.clk)
        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    print(f"
Summary: {passed}/{total} tests passed")
    if passed < total:
        raise TestFailure(f"Only {passed} out of {total} tests passed")