import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_factorize_basic(dut):
    """Test basic factorization cases"""
    # Setup clock
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
    
    test_cases = [
        (2, [2]),
        (4, [2, 2]),
        (8, [2, 2, 2]),
        (57, [3, 19]),
        (1083, [3, 3, 19, 19]),
        (3249, [3, 3, 3, 19, 19, 19]),
        (6859, [19, 19, 19]),
        (18, [2, 3, 3]),
    ]
    
    for test_num, expected_factors in test_cases:
        dut.n.value = test_num
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        factors_found = []
        timeout = 500
        
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.factors_valid.value == 1:
                factors_found.append(int(dut.factors_out.value))
            if dut.done.value == 1:
                break
        else:
            raise TestFailure(f"Timeout for n={test_num}")
        
        if factors_found != expected_factors:
            raise TestFailure(f"n={test_num}: expected {expected_factors}, got {factors_found}")
        
        dut._log.info(f"n={test_num}: {factors_found} == {expected_factors} ✓")
    
    dut._log.info("All basic tests passed!")

@cocotb.test()
async def test_factorize_edge_cases(dut):
    """Test edge cases and larger numbers"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    edge_cases = [
        (1, []),  # Edge case: 1 has no prime factors
        (3, [3]),  # Prime number
        (25, [5, 5]),  # Square of prime
        (37, [37]),  # Another prime
        (49, [7, 7]),  # 7^2
        (255, [3, 5, 17]),  # Product of three primes
    ]
    
    for test_num, expected_factors in edge_cases:
        dut.n.value = test_num
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        factors_found = []
        timeout = 500
        
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.factors_valid.value == 1:
                factors_found.append(int(dut.factors_out.value))
            if dut.done.value == 1:
                break
        else:
            raise TestFailure(f"Timeout for n={test_num}")
        
        if factors_found != expected_factors:
            raise TestFailure(f"n={test_num}: expected {expected_factors}, got {factors_found}")
        
        dut._log.info(f"Edge case n={test_num}: {factors_found} ✓")
    
    dut._log.info("All edge case tests passed!")