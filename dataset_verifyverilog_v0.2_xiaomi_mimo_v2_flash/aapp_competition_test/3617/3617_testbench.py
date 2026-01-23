import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure
import random

# Helper for LFSR (to verify DUT)
def lfsr_next(val):
    # 16-bit LFSR with polynomial 0x8005 (Galois)
    bit = val & 1
    val >>= 1
    if bit:
        val ^= 0x8005
    return val

# Helper for sorting
def python_sort_and_calc(t0, T):
    # Generate sequence
    seq = [t0]
    val = t0
    for _ in range(15):
        val = lfsr_next(val)
        seq.append(val)
    
    # Sort
    seq.sort()
    
    # Calc
    count = 0
    penalty = 0
    accum_time = 0
    MOD = 1000000007
    
    for t in seq:
        accum_time += t
        if accum_time <= T:
            count += 1
            penalty = (penalty + accum_time) % MOD
        else:
            break
    return count, penalty

@cocotb.test()
async def test_pikeman_solver(dut):
    """Test the Pikeman Solver Module"""
    
    # Setup Clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.t0.value = 0
    dut.T.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: Small N, exact fit
    dut._log.info("Running Test Case 1")
    t0_1 = 2
    T_1 = 10
    expected_count_1, expected_penalty_1 = python_sort_and_calc(t0_1, T_1)
    
    dut.t0.value = t0_1
    dut.T.value = T_1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    cycles = 0
    while dut.done.value == 0 and cycles < 200:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if cycles >= 200:
        raise TestFailure("Test 1: Timeout (modules did not finish in 200 cycles)")
        
    # Check result
    count_val = int(dut.count.value)
    penalty_val = int(dut.penalty.value)
    
    if count_val != expected_count_1:
        raise TestFailure(f"Test 1 Count Mismatch: Expected {expected_count_1}, got {count_val}")
    if penalty_val != expected_penalty_1:
        raise TestFailure(f"Test 1 Penalty Mismatch: Expected {expected_penalty_1}, got {penalty_val}")
    
    dut._log.info(f"Test 1 Passed: Count={count_val}, Penalty={penalty_val}")
    await RisingEdge(dut.clk)

    # Test Case 2: Very large T, solve all
    dut._log.info("Running Test Case 2")
    t0_2 = 100
    T_2 = 1000000
    expected_count_2, expected_penalty_2 = python_sort_and_calc(t0_2, T_2)
    
    dut.t0.value = t0_2
    dut.T.value = T_2
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while dut.done.value == 0 and cycles < 200:
        await RisingEdge(dut.clk)
        cycles += 1
        
    if cycles >= 200:
        raise TestFailure("Test 2: Timeout")
        
    if int(dut.count.value) != expected_count_2 or int(dut.penalty.value) != expected_penalty_2:
        raise TestFailure(f"Test 2 Failed: Expected {expected_count_2} {expected_penalty_2}, got {int(dut.count.value)} {int(dut.penalty.value)}")
    
    dut._log.info(f"Test 2 Passed: Count={int(dut.count.value)}, Penalty={int(dut.penalty.value)}")
    await RisingEdge(dut.clk)

    # Test Case 3: Tight constraint
    dut._log.info("Running Test Case 3")
    t0_3 = 50
    T_3 = 150
    expected_count_3, expected_penalty_3 = python_sort_and_calc(t0_3, T_3)
    
    dut.t0.value = t0_3
    dut.T.value = T_3
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while dut.done.value == 0 and cycles < 200:
        await RisingEdge(dut.clk)
        cycles += 1

    if cycles >= 200:
        raise TestFailure("Test 3: Timeout")

    if int(dut.count.value) != expected_count_3 or int(dut.penalty.value) != expected_penalty_3:
        raise TestFailure(f"Test 3 Failed: Expected {expected_count_3} {expected_penalty_3}, got {int(dut.count.value)} {int(dut.penalty.value)}")

    dut._log.info(f"Test 3 Passed: Count={int(dut.count.value)}, Penalty={int(dut.penalty.value)}")
    
    dut._log.info("All tests passed successfully!")