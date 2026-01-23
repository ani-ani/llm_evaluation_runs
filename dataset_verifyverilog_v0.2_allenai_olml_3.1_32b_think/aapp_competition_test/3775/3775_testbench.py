import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_deduce_common(dut):
    # Clock generation
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n_a.value = 0
    dut.m_b.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Helper tasks
    async def run_test(n_a_val, m_b_val, set_a_flat, set_b_flat, expected):
        dut.n_a.value = n_a_val
        dut.m_b.value = m_b_val
        
        # Set A: 8 pairs, 2 nums each, 4 bits each. Total 8*2*4 = 64 bits (flattened)
        # In Python, we construct the value. Input is [7:0][1:0][3:0].
        # Let's assume set_a_flat is a list of 8 pairs, each pair is (num1, num2). 0 if empty.
        val_a = 0
        for i in range(8):
            if i < len(set_a_flat):
                n1, n2 = set_a_flat[i]
            else:
                n1, n2 = 0, 0
            # Position: pair i, num 0 (msb), num 1 (lsb)
            # Bit offset: i*8 + 4 (for num 0) and i*8 (for num 1) ? 
            # [7:0][1:0][3:0]. 
            # Pair 0: index 0. bits [7][1][3:0] = index 0*8 + 1*4 + 0 -> 12? No, let's do raw unpacked access.
            # In cocotb, we can assign the whole array if we flatten it right.
            # The spec says [7:0][1:0][3:0]. 
            # Let's iterate python list and assign to dut.set_a[i][j].
            dut.set_a[i][0].value = n1
            dut.set_a[i][1].value = n2
        
        for i in range(8):
            if i < len(set_b_flat):
                n1, n2 = set_b_flat[i]
            else:
                n1, n2 = 0, 0
            dut.set_b[i][0].value = n1
            dut.set_b[i][1].value = n2

        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 0
        while not dut.done.value and timeout < 10:
            await RisingEdge(dut.clk)
            timeout += 1
            
        if not dut.done.value:
            raise TestFailure(f"Module did not assert done within 10 cycles")
            
        actual = int(dut.result.value)
        if actual != expected:
            raise TestFailure(f"Expected {expected}, got {actual}")
        
        # Reset for next test
        dut.start.value = 0
        await RisingEdge(dut.clk)

    # Test 1: Example 1 -> Output 1
    # 2 2
    # 1 2 3 4
    # 1 5 3 4
    # Candidates: (1,2) & (1,5) -> 1. (1,2) & (3,4) -> none. (3,4) & (1,5) -> none. (3,4) & (3,4) -> identical (skip).
    # Only candidate is 1. Expect 1.
    await run_test(2, 2, [(1,2), (3,4)], [(1,5), (3,4)], 1)

    # Test 2: Example 2 -> Output 0
    # 2 2
    # 1 2 3 4
    # 1 5 6 4
    # Candidates: (1,2)&(1,5) -> 1. (3,4)&(6,4) -> 4. Set = {1, 4}.
    # Determinism:
    # P1 Pair (1,2): matches B pairs? (1,5) -> 1. So {1}. OK.
    # P1 Pair (3,4): matches B pairs? (6,4) -> 4. So {4}. OK.
    # P2 Pair (1,5): matches A pairs? (1,2) -> 1. So {1}. OK.
    # P2 Pair (6,4): matches A pairs? (3,4) -> 4. So {4}. OK.
    # All deterministic. Expect 0.
    await run_test(2, 2, [(1,2), (3,4)], [(1,5), (6,4)], 0)

    # Test 3: Example 3 -> Output -1
    # 2 3
    # 1 2 4 5
    # 1 2 1 3 2 3
    # Candidates:
    # (1,2) & (1,2) -> same
    # (1,2) & (1,3) -> 1
    # (1,2) & (2,3) -> 2
    # (4,5) & (1,2) -> none
    # (4,5) & (1,3) -> none
    # (4,5) & (2,3) -> none
    # Candidates = {1, 2}
    # Determinism check:
    # P1 (1,2): matches {1, 2} -> possibilities {1, 2}. Size 2 > 1. Determinism FAILS.
    # Expect -1.
    await run_test(2, 3, [(1,2), (4,5)], [(1,2), (1,3), (2,3)], -1)

    # Test 4: Edge case - Multiple matches but single candidate (e.g. 1 and 1 via different pairs)
    # 2 2
    # 1 2 1 3
    # 1 4 1 5
    # (1,2)&(1,4)->1, (1,2)&(1,5)->1, (1,3)&(1,4)->1, (1,3)&(1,5)->1
    # Candidates = {1}. Expect 1.
    await run_test(2, 2, [(1,2), (1,3)], [(1,4), (1,5)], 1)

    # Test 5: Determinism failure on second participant
    # 1 2
    # 1 2
    # 1 3 2 3
    # (1,2)&(1,3)->1, (1,2)&(2,3)->2. Candidates {1,2}.
    # P1 (1,2) -> possibilities {1,2} (fail).
    # P2 (1,3) -> possibilities {1}. OK.
    # P2 (2,3) -> possibilities {2}. OK.
    # Expect -1.
    await run_test(1, 2, [(1,2)], [(1,3), (2,3)], -1)

    print("All tests passed!")
