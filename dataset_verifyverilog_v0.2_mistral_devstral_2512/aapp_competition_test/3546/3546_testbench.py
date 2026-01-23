import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_theorem_proof_minimizer(dut):
    """Test the theorem proof minimizer module"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: Simple case (Sample Input 1)
    # n=2, theorem 0: 2 proofs (10 deps: none, 3 deps: theorem 1)
    # theorem 1: 1 proof (4 deps: theorem 0)
    # Expected: 10 (choose first proof of theorem 0, no dependencies)
    dut.num_theorems.value = 2
    
    # Proof counts
    dut.proof_count[0].value = 2
    dut.proof_count[1].value = 1
    
    # Proof 0-0: length 10, 0 dependencies
    dut.proof_length[0].value = 10
    dut.proof_dep_count[0].value = 0
    
    # Proof 0-1: length 3, 1 dependency (theorem 1)
    dut.proof_length[1].value = 3
    dut.proof_dep_count[1].value = 1
    dut.proof_deps[1][0].value = 1
    
    # Proof 1-0: length 4, 1 dependency (theorem 0)
    dut.proof_length[2].value = 4
    dut.proof_dep_count[2].value = 1
    dut.proof_deps[2][0].value = 0
    
    # Fill unused slots
    for i in range(3, 200):
        dut.proof_length[i].value = 0
        dut.proof_dep_count[i].value = 0
        for j in range(20):
            dut.proof_deps[i][j].value = 31
    
    for i in range(2, 20):
        dut.proof_count[i].value = 0
    
    # Start computation
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (with timeout)
    timeout = 2000
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    else:
        assert False, "Timeout waiting for done"
    
    # Check result
    result = int(dut.min_length.value)
    print(f"Test 1: Result = {result}, Expected = 10")
    assert result == 10, f"Test 1 failed: got {result}, expected 10"
    
    await RisingEdge(dut.clk)
    await Timer(100, units='ns')
    
    # Test Case 2: More complex (Sample Input 2 adapted)
    # Reset for next test
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # n=4
    # Theorem 0: 2 proofs (1 dep: [1,3], cost=1), (5 dep: [2], cost=5)
    # Theorem 1: 1 proof (2 dep: [2], cost=2)
    # Theorem 2: 1 proof (0 dep, cost=0)
    # Theorem 3: 2 proofs (2 dep: [0], cost=2), (1 dep: [1], cost=1)
    # Expected: 4 (proof0-0 (1) + proof1-0 (2) + proof2-0 (0) + proof3-1 (1) = 4)
    
    dut.num_theorems.value = 4
    
    # Proof counts
    dut.proof_count[0].value = 2
    dut.proof_count[1].value = 1
    dut.proof_count[2].value = 1
    dut.proof_count[3].value = 2
    for i in range(4, 20):
        dut.proof_count[i].value = 0
    
    # Theorem 0, proof 0
    dut.proof_length[0].value = 1
    dut.proof_dep_count[0].value = 2
    dut.proof_deps[0][0].value = 1
    dut.proof_deps[0][1].value = 3
    
    # Theorem 0, proof 1
    dut.proof_length[1].value = 5
    dut.proof_dep_count[1].value = 1
    dut.proof_deps[1][0].value = 2
    
    # Theorem 1, proof 0
    dut.proof_length[2].value = 2
    dut.proof_dep_count[2].value = 1
    dut.proof_deps[2][0].value = 2
    
    # Theorem 2, proof 0
    dut.proof_length[3].value = 0
    dut.proof_dep_count[3].value = 0
    
    # Theorem 3, proof 0
    dut.proof_length[4].value = 2
    dut.proof_dep_count[4].value = 1
    dut.proof_deps[4][0].value = 0
    
    # Theorem 3, proof 1
    dut.proof_length[5].value = 1
    dut.proof_dep_count[5].value = 1
    dut.proof_deps[5][0].value = 1
    
    # Reset unused
    for i in range(6, 200):
        dut.proof_length[i].value = 0
        dut.proof_dep_count[i].value = 0
        for j in range(20):
            dut.proof_deps[i][j].value = 31
    
    # Start
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait
    timeout = 2000
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    else:
        assert False, "Timeout waiting for done"
    
    result = int(dut.min_length.value)
    print(f"Test 2: Result = {result}, Expected = 4")
    assert result == 4, f"Test 2 failed: got {result}, expected 4"
    
    # Test Case 3: Independent theorems
    # Reset
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # n=3
    # Theorem 0: 2 proofs (cost 100, 50) both no deps
    # Expected: 50
    
    dut.num_theorems.value = 3
    dut.proof_count[0].value = 2
    dut.proof_count[1].value = 0
    dut.proof_count[2].value = 0
    for i in range(3, 20):
        dut.proof_count[i].value = 0
    
    dut.proof_length[0].value = 100
    dut.proof_dep_count[0].value = 0
    
    dut.proof_length[1].value = 50
    dut.proof_dep_count[1].value = 0
    
    for i in range(2, 200):
        dut.proof_length[i].value = 0
        dut.proof_dep_count[i].value = 0
        for j in range(20):
            dut.proof_deps[i][j].value = 31
    
    # Start
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait
    timeout = 2000
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    else:
        assert False, "Timeout waiting for done"
    
    result = int(dut.min_length.value)
    print(f"Test 3: Result = {result}, Expected = 50")
    assert result == 50, f"Test 3 failed: got {result}, expected 50"
    
    print(f"
All tests completed successfully!")
