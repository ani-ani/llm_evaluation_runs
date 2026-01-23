import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

@cocotb.test()
async def test_partition_puzzle(dut):
    """Test partition puzzle solver with scaled-down inputs"""
    
    # Generate clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    dut.k.value = 0
    for i in range(8):
        setattr(dut, f'v{i}', 0)
    
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: n=5, k=3, values=[10,5,4,8,3]
    # LPF: 10->5, 5->5, 4->2, 8->2, 3->3
    # Best partition: [10,5]=min(5,5)=5, [4,8]=min(2,2)=2, [3]=3 => score=min(5,2,3)=2
    dut.n.value = 5
    dut.k.value = 3
    dut.v0.value = 10
    dut.v1.value = 5
    dut.v2.value = 4
    dut.v3.value = 8
    dut.v4.value = 3
    dut.v5.value = 0
    dut.v6.value = 0
    dut.v7.value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 0
    while dut.done.value == 0 and timeout < 500:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if dut.max_score.value != 2:
        raise TestFailure(f"Test 1 failed: expected 2, got {int(dut.max_score.value)}")
    print(f"Test 1 passed: max_score={int(dut.max_score.value)}")
    
    # Reset for next test
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 2: n=5, k=3, values=[10,11,12,13,14]
    # LPF: 10->5, 11->11, 12->3, 13->13, 14->7
    # Any partition will have at least one region with score 0? Wait: all have primes.
    # But we need min across region. Let's find best.
    # Example: [10,11]=min(5,11)=5, [12,13]=min(3,13)=3, [14]=7 => score=3
    # But wait, [11,12]=min(11,3)=3, [13,14]=min(13,7)=7, [10]=5 => score=3
    # Actually, let's check if we can get 0: no, all have primes.
    # Hmm, but Python output says 0... Wait, let me recalculate.
    # 12 divisors: 2,3. Largest prime is 3. 
    # 10->5, 11->11, 12->3, 13->13, 14->7
    # Partition: [10,11,12,13,14] into 3 regions.
    # [10,11]=5, [12,13]=3, [14]=7 => min=3
    # [10,11,12]=min(5,11,3)=3, [13,14]=min(13,7)=7 => min=3
    # Wait, output says 0. Why?
    # Oh! "largest prime number that divides every number" means GCD of all numbers in region, then largest prime factor of that GCD.
    # If GCD of region is 1, no common prime, score=0.
    # 10,11: GCD=1 => score 0
    # 12,13: GCD=1 => score 0
    # 14: GCD=14 => largest prime factor 7
    # So any region with two numbers that don't share a prime factor scores 0.
    # [10,11,12,13,14]: best partition? [10], [11], [12,13,14]
    # [10] score=5, [11] score=11, [12,13,14] GCD=1 => score 0
    # [10,11]=0, [12]=3, [13,14]=0 => min=0
    # [10,11,12]=0, [13,14]=0, [14]=7 wait. [10,11,12]: GCD(10,11)=1 => 0
    # So any region with mixed numbers likely 0 unless they share factors.
    # Best might be [10], [11], [12], [13], [14] but k=3, so we must combine.
    # [10,11]=0, [12,13]=0, [14]=7 => min=0
    # Yes, so output 0.
    
    dut.n.value = 5
    dut.k.value = 3
    dut.v0.value = 10
    dut.v1.value = 11
    dut.v2.value = 12
    dut.v3.value = 13
    dut.v4.value = 14
    dut.v5.value = 0
    dut.v6.value = 0
    dut.v7.value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while dut.done.value == 0 and timeout < 500:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if dut.max_score.value != 0:
        raise TestFailure(f"Test 2 failed: expected 0, got {int(dut.max_score.value)}")
    print(f"Test 2 passed: max_score={int(dut.max_score.value)}")
    
    # Reset
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 3: n=5, k=3, values=[10,8,12,11,14]
    # LPF/GCD analysis: 
    # 10: LPF=5, 8: LPF=2, 12: LPF=3, 11: LPF=11, 14: LPF=7
    # Need regions with common GCD > 1
    # [10,8,12]: GCD=2 => largest prime 2 => score 2
    # [11,14]: GCD=1 => score 0
    # [10,8]: GCD=2 => score 2, [12,11]: GCD=1 => 0, [14]:7 => min=0
    # [10,8]=2, [12]=3, [11,14]=0 => min=0
    # [10,8,12,11]: GCD=1 => 0, [14]=7 => 0
    # Wait, output says 2. How?
    # Let's find [10,8,12,11,14] partition into 3:
    # [10,8] GCD=2, [12] GCD=12 => 3, [11,14] GCD=1 => 0. Min=0.
    # [10,8,12] GCD=2 => 2, [11] GCD=11 => 11, [14] GCD=14 => 7. Min=2. YES!
    # So partition is [10,8,12], [11], [14]. Score min(2, 11, 7) = 2.
    
    dut.n.value = 5
    dut.k.value = 3
    dut.v0.value = 10
    dut.v1.value = 8
    dut.v2.value = 12
    dut.v3.value = 11
    dut.v4.value = 14
    dut.v5.value = 0
    dut.v6.value = 0
    dut.v7.value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while dut.done.value == 0 and timeout < 500:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if dut.max_score.value != 2:
        raise TestFailure(f"Test 3 failed: expected 2, got {int(dut.max_score.value)}")
    print(f"Test 3 passed: max_score={int(dut.max_score.value)}")
    
    # Additional edge case test
    # Test case 4: All same number, n=4, k=2
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.n.value = 4
    dut.k.value = 2
    dut.v0.value = 6
    dut.v1.value = 6
    dut.v2.value = 6
    dut.v3.value = 6
    dut.v4.value = 0
    dut.v5.value = 0
    dut.v6.value = 0
    dut.v7.value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while dut.done.value == 0 and timeout < 500:
        await RisingEdge(dut.clk)
        timeout += 1
    
    # GCD=6 => largest prime 3. Score 3.
    if dut.max_score.value != 3:
        raise TestFailure(f"Test 4 failed: expected 3, got {int(dut.max_score.value)}")
    print(f"Test 4 passed: max_score={int(dut.max_score.value)}")
    
    print("All 4/4 tests passed")
