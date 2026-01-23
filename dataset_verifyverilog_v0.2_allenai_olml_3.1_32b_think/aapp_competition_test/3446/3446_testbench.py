import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure
import random

@cocotb.test()
async def test_assembly_optimizer(dut):
    """Test the assembly optimizer module"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")  # 100 MHz
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    print("
=== Assembly Optimizer Test Suite ===")
    
    # Test Case 1: Original sample - aba
    # Symbols: a=0, b=1
    # Table: a-a: 3->b, a-b: 5->b, b-a: 6->a, b-b: 2->b
    # Sequence: a(0), b(1), a(0) = [0,1,0]
    # Expected: 9-b (9 -> b)
    
    dut.num_symbols.value = 2
    dut.seq_length.value = 3
    dut.sequence[0].value = 0
    dut.sequence[1].value = 1
    dut.sequence[2].value = 0
    
    # Time table (Q16.16: multiply by 65536)
    # a-a: 3, a-b: 5, b-a: 6, b-b: 2
    dut.time_table[0][0].value = 3 * 65536
    dut.time_table[0][1].value = 5 * 65536
    dut.time_table[1][0].value = 6 * 65536
    dut.time_table[1][1].value = 2 * 65536
    
    # Result table: 0=a, 1=b
    # a-a->b=1, a-b->b=1, b-a->a=0, b-b->b=1
    dut.result_table[0][0].value = 1
    dut.result_table[0][1].value = 1
    dut.result_table[1][0].value = 0
    dut.result_table[1][1].value = 1
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (max 1000 cycles)
    timeout = 0
    while not dut.done.value and timeout < 1500:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 1500:
        raise TestFailure("Test 1: Timeout - computation did not finish")
    
    # Check results
    # Time should be 9, result should be 1 (b)
    expected_time = 9 * 65536
    expected_result = 1
    
    actual_time = int(dut.min_time.value)
    actual_result = int(dut.result_symbol.value)
    
    print(f"Test 1 (aba): Expected time=9 ({expected_time}), result=b (1)")
    print(f"Test 1 (aba): Actual time={actual_time // 65536}, result={actual_result}")
    
    if abs(actual_time - expected_time) > 1000:  # Allow small rounding
        raise TestFailure(f"Test 1: Time mismatch. Expected {expected_time}, got {actual_time}")
    if actual_result != expected_result:
        raise TestFailure(f"Test 1: Result mismatch. Expected {expected_result}, got {actual_result}")
    
    print("Test 1: PASSED
")
    
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    # Test Case 2: Original sample - bba
    # Sequence: b(1), b(1), a(0) = [1,1,0]
    # Expected: 8-a (8 -> a)
    
    dut.seq_length.value = 3
    dut.sequence[0].value = 1
    dut.sequence[1].value = 1
    dut.sequence[2].value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 1500:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 1500:
        raise TestFailure("Test 2: Timeout")
    
    expected_time = 8 * 65536
    expected_result = 0  # a
    actual_time = int(dut.min_time.value)
    actual_result = int(dut.result_symbol.value)
    
    print(f"Test 2 (bba): Expected time=8, result=a (0)")
    print(f"Test 2 (bba): Actual time={actual_time // 65536}, result={actual_result}")
    
    if abs(actual_time - expected_time) > 1000:
        raise TestFailure(f"Test 2: Time mismatch")
    if actual_result != expected_result:
        raise TestFailure(f"Test 2: Result mismatch")
    
    print("Test 2: PASSED
")
    
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    # Test Case 3: Single symbol
    # Sequence: a(0)
    # Expected: 0-a
    
    dut.num_symbols.value = 2
    dut.seq_length.value = 1
    dut.sequence[0].value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 1500:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 1500:
        raise TestFailure("Test 3: Timeout")
    
    expected_time = 0
    expected_result = 0  # a
    actual_time = int(dut.min_time.value)
    actual_result = int(dut.result_symbol.value)
    
    print(f"Test 3 (a): Expected time=0, result=a (0)")
    print(f"Test 3 (a): Actual time={actual_time // 65536}, result={actual_result}")
    
    if actual_time != 0:
        raise TestFailure(f"Test 3: Time should be 0")
    if actual_result != expected_result:
        raise TestFailure(f"Test 3: Result mismatch")
    
    print("Test 3: PASSED
")
    
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    # Test Case 4: Two symbols
    # Sequence: a(0), b(1)
    # Expected: 5-b (a-b = 5, result b)
    
    dut.seq_length.value = 2
    dut.sequence[0].value = 0
    dut.sequence[1].value = 1
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 1500:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 1500:
        raise TestFailure("Test 4: Timeout")
    
    expected_time = 5 * 65536
    expected_result = 1  # b
    actual_time = int(dut.min_time.value)
    actual_result = int(dut.result_symbol.value)
    
    print(f"Test 4 (ab): Expected time=5, result=b (1)")
    print(f"Test 4 (ab): Actual time={actual_time // 65536}, result={actual_result}")
    
    if abs(actual_time - expected_time) > 1000:
        raise TestFailure(f"Test 4: Time mismatch")
    if actual_result != expected_result:
        raise TestFailure(f"Test 4: Result mismatch")
    
    print("Test 4: PASSED
")
    
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    # Test Case 5: Tie-breaking test
    # Custom table where two results have same time
    # a-a: 5->a, a-b: 5->b, b-a: 0->a, b-b: 0->b
    # Sequence: a, a, a
    # Two ways: (aa)a = 5-a + 0-a = 5-a
    #           a(aa) = 0-a + 5-a = 5-a
    # Both result in a with time 5
    
    dut.num_symbols.value = 2
    dut.seq_length.value = 3
    dut.sequence[0].value = 0
    dut.sequence[1].value = 0
    dut.sequence[2].value = 0
    
    dut.time_table[0][0].value = 5 * 65536
    dut.time_table[0][1].value = 5 * 65536
    dut.time_table[1][0].value = 0 * 65536
    dut.time_table[1][1].value = 0 * 65536
    
    dut.result_table[0][0].value = 0
    dut.result_table[0][1].value = 1
    dut.result_table[1][0].value = 0
    dut.result_table[1][1].value = 1
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 1500:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 1500:
        raise TestFailure("Test 5: Timeout")
    
    expected_time = 5 * 65536
    expected_result = 0  # a (tie-breaking prefers a over b)
    actual_time = int(dut.min_time.value)
    actual_result = int(dut.result_symbol.value)
    
    print(f"Test 5 (aaa, tie): Expected time=5, result=a (0)")
    print(f"Test 5 (aaa, tie): Actual time={actual_time // 65536}, result={actual_result}")
    
    if abs(actual_time - expected_time) > 1000:
        raise TestFailure(f"Test 5: Time mismatch")
    if actual_result != expected_result:
        raise TestFailure(f"Test 5: Tie-breaking failed, expected a (0), got {actual_result}")
    
    print("Test 5: PASSED
")
    
    print("=== All tests passed! ===")
    
    # Count passed tests
    print("Summary: 5/5 tests passed")