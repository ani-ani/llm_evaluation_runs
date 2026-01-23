import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_dna_program_comparator(dut):
    """Test DNA program equivalence checking"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.op_type.value = 0
    dut.op_pos.value = 0
    dut.op_char.value = 0
    dut.program_sel.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    async def load_program(program_sel, operations):
        """Load operations for one program"""
        dut.program_sel.value = program_sel
        for op in operations:
            dut.op_type.value = op[0]
            dut.op_pos.value = op[1]
            dut.op_char.value = op[2] if len(op) > 2 else 0
            await RisingEdge(dut.clk)
        # Send end marker
        dut.op_type.value = 3  # END
        await RisingEdge(dut.clk)
    
    async def run_test(name, prog1, prog2, expected):
        """Run a single test case"""
        print(f"
Test: {name}")
        
        # Reset state
        dut.start.value = 0
        await RisingEdge(dut.clk)
        
        # Load programs
        await load_program(0, prog1)
        await load_program(1, prog2)
        
        # Start comparison
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        timeout = 100
        for _ in range(timeout):
            if dut.done.value:
                break
            await RisingEdge(dut.clk)
        else:
            raise TestFailure(f"Timeout in test {name}")
        
        # Check result
        actual = int(dut.result.value)
        print(f"Expected: {expected}, Actual: {actual}")
        if actual != expected:
            raise TestFailure(f"Test {name} failed: expected {expected}, got {actual}")
        print("PASSED")
    
    # Test 1: Del(1) Del(2) vs Del(3) Del(1) -> identical
    # Simplified: Del(1), Del(1) vs Del(1), Del(1) (after adjustment)
    await run_test(
        "Test1: Del(1) Del(2) vs Del(3) Del(1)",
        [(2, 1, 0), (2, 2, 0)],  # D1, D2
        [(2, 3, 0), (2, 1, 0)],  # D3, D1
        0  # identical
    )
    
    # Test 2: Del(2) Del(1) vs Del(1) Del(2) -> different
    await run_test(
        "Test2: Del(2) Del(1) vs Del(1) Del(2)",
        [(2, 2, 0), (2, 1, 0)],  # D2, D1
        [(2, 1, 0), (2, 2, 0)],  # D1, D2
        1  # different
    )
    
    # Test 3: I1 X D1 vs empty -> identical
    await run_test(
        "Test3: I1 X D1 vs empty",
        [(1, 1, ord('X')), (2, 1, 0)],  # I1 X, D1
        [],  # empty
        0  # identical
    )
    
    # Test 4: I14 B I14 A vs I14 A I15 B -> identical
    await run_test(
        "Test4: I14 B I14 A vs I14 A I15 B",
        [(1, 14, ord('B')), (1, 14, ord('A'))],  # I14 B, I14 A
        [(1, 14, ord('A')), (1, 15, ord('B'))],  # I14 A, I15 B
        0  # identical
    )
    
    # Test 5: I14 A I15 B vs I14 B I15 A -> different
    await run_test(
        "Test5: I14 A I15 B vs I14 B I15 A",
        [(1, 14, ord('A')), (1, 15, ord('B'))],  # I14 A, I15 B
        [(1, 14, ord('B')), (1, 15, ord('A'))],  # I14 B, I15 A
        1  # different
    )
    
    print("
=== All tests completed ===")
    print(f"Summary: 5/5 tests passed")