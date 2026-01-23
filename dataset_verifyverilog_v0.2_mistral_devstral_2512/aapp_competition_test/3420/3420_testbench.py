import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_book_circle(dut):
    # Test cases mapping: (boy_count, girl_count, adj_matrix, expected_result)
    test_cases = [
        # Case 1: Perfect matching - 2 presentations
        (
            2, 2,
            [
                [1, 0],  # boy0 connected to girl0
                [0, 1]   # boy1 connected to girl1
            ],
            2
        ),
        # Case 2: One boy with two books - 1 presentation  
        (
            1, 2,
            [
                [1, 1]  # boy0 connected to both girls
            ],
            1
        ),
        # Case 3: No books - 0 presentations
        (
            2, 2,
            [
                [0, 0],
                [0, 0]
            ],
            0
        ),
        # Case 4: Complete bipartite - min of B,G
        (
            3, 2,
            [
                [1, 1],
                [1, 1],
                [1, 1]
            ],
            2
        ),
        # Case 5: Chain: boy0-girl0, boy1-girl0, boy1-girl1
        (
            2, 2,
            [
                [1, 0],
                [1, 1]
            ],
            2  # max matching = 2
        )
    ]
    
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.boy_count.value = 0
    dut.girl_count.value = 0
    for i in range(8):
        for j in range(8):
            dut.adj_matrix[i].value[j] = 0
    
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    passed = 0
    total = len(test_cases)
    
    for i, (b_count, g_count, matrix, expected) in enumerate(test_cases):
        print(f"Running test case {i+1}: B={b_count}, G={g_count}, Expected={expected}")
        
        # Set inputs
        dut.boy_count.value = b_count
        dut.girl_count.value = g_count
        
        # Set adjacency matrix
        for b in range(8):
            for g in range(8):
                if b < b_count and g < g_count:
                    dut.adj_matrix[b].value[g] = matrix[b][g]
                else:
                    dut.adj_matrix[b].value[g] = 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (with timeout)
        cycles = 0
        while not dut.done.value and cycles < 1000:
            await RisingEdge(dut.clk)
            cycles += 1
        
        if cycles >= 1000:
            raise TestFailure(f"Test {i+1}: Timeout after 1000 cycles")
        
        # Check result
        actual = int(dut.result.value)
        if actual == expected:
            passed += 1
            print(f"  PASSED: result={actual}")
        else:
            print(f"  FAILED: expected={expected}, got={actual}")
            raise TestFailure(f"Test {i+1}: Expected {expected}, got {actual}")
        
        # Wait a bit before next test
        await RisingEdge(dut.clk)
    
    print(f"
=== Summary: {passed}/{total} tests passed ===")
    
    if passed != total:
        raise TestFailure(f"Only {passed}/{total} tests passed")
