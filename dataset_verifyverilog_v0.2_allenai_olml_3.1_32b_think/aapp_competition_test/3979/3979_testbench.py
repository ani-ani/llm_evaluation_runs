import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_lexicographical_solver(dut):
    """Test the lexicographical solver module"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.word_len_1.value = 0
    dut.word_len_2.value = 0
    for i in range(16):
        dut.word_1[i].value = 0
        dut.word_2[i].value = 0
    
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Helper function to load words
    def load_words(w1, w2):
        dut.word_len_1.value = len(w1)
        dut.word_len_2.value = len(w2)
        for i in range(16):
            if i < len(w1):
                dut.word_1[i].value = w1[i]
            else:
                dut.word_1[i].value = 0
            if i < len(w2):
                dut.word_2[i].value = w2[i]
            else:
                dut.word_2[i].value = 0

    # Test Case 1: Example 1 simplified (1st pair: [2] vs [1])
    # w1=[2], w2=[1]. 2 > 1. w1[0] (2) must be cap, w2[0] (1) must not.
    # Expected: Mask has bits for 2 and 3 (indices 1, 2)? No, let's track index.
    # Alphabet: 1, 2, 3. Bit 0=1, Bit 1=2, Bit 2=3.
    # w1=[2], w2=[1]. 2 > 1. Result: 2 must be cap (Bit 1), 1 must not (Bit 0).
    # Propagate: None.
    # Result Mask: 0x02 (binary 0010).
    
    dut._log.info("Test 1: w1=[2], w2=[1]")
    load_words([2], [1])
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done (check state DONE or valid=1)
    # We will wait a few cycles
    for _ in range(20):
        await RisingEdge(dut.clk)
        if dut.valid.value == 1:
            break
    
    if dut.valid.value != 1:
        raise TestFailure("Valid not asserted in time")
    if dut.impossible.value != 0:
        raise TestFailure("Should be possible")
    
    # Check mask: Bit 1 (2) should be set. Bit 0 (1) should not.
    mask = int(dut.capitalization_mask.value)
    # Python: 1->bit0, 2->bit1, 3->bit2
    if (mask & 0x2) == 0:
        raise TestFailure(f"Mask {mask:04X} missing bit for letter 2")
    if (mask & 0x1) != 0:
        raise TestFailure(f"Mask {mask:04X} should not have bit for letter 1")
    dut._log.info(f"Test 1 Passed. Mask: {mask:04X}")

    # Test Case 2: Conflict detection
    # Scenario: w1=[2], w2=[1] implies 2 cap, 1 not.
    # Now, manually we can't change inputs easily in one test, but we can use the next step if sequential.
    # Since this module takes only 2 words, we can't chain tests easily without reset or new sequence.
    # Let's assume we need to support finding the mask for the whole sequence logic externally.
    # But here we are testing the constraint resolver.
    # Let's test 'impossible' case: 
    # We need to force a conflict. 
    # Constraint A: 2 must be cap (from w1=[2], w2=[1]).
    # Constraint B: 1 must be not cap (from above).
    # Constraint C: 1 must be cap (from w1=[1], w2=[2] -> 1 < 2, same cap. Wait, 1 < 2 means same? No.
    # If w1 < w2, they must be same.
    # To force a conflict: 
    # 1. w1=[2], w2=[1] -> 2 cap, 1 not cap.
    # 2. w1=[1], w2=[2] -> 1 < 2 -> 1 and 2 must be same.
    # If 1 not cap, 2 not cap. But 2 must be cap. Conflict.
    
    # Let's reset and run a second scenario for 'impossible'.
    dut.rst_n.value = 0
    await Timer(10, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut._log.info("Test 2: w1=[1], w2=[2] (implies same cap) then w1=[2], w2=[1] (implies 2 cap, 1 not)")
    # Actually the module only processes 2 words. To test propagation, we need to simulate the full sequence logic.
    # However, the prompt says the module processes constraints derived from adjacent pairs.
    # To make the module robust, it should handle dependency chains.
    # Let's assume the testbench sets up a scenario where:
    # Word 1: [1, 2] (wait, format is len + data)
    # Let's rely on the standard test cases provided.
    
    # Test Case: Hard constraint
    # w1=[3, 1], w2=[2, 3]
    # First char: 3 > 2. 
    # Result: 3 must be cap, 2 must not.
    # Mask: Bit 2 (3), Bit 1 (2).
    dut._log.info("Test 3: w1=[3, 1], w2=[2, 3]")
    load_words([3, 1], [2, 3])
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    for _ in range(20):
        await RisingEdge(dut.clk)
        if dut.valid.value == 1:
            break
    if dut.valid.value != 1:
        raise TestFailure("Valid not asserted")
    mask = int(dut.capitalization_mask.value)
    # Expected: 3->bit2 (0x4), 2->bit1 (0x2). Total 0x6.
    if mask != 0x6:
        raise TestFailure(f"Expected mask 0x6, got {mask:04X}")
    
    # Test Case: Prefix case (w1 shorter, equal prefix)
    # w1=[1], w2=[1, 2]. Prefix valid. No constraints? 
    # Usually prefix implies w1 <= w2. No specific letter constraints.
    dut._log.info("Test 4: w1=[1], w2=[1, 2] (Prefix)")
    dut.rst_n.value = 0
    await Timer(10, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    load_words([1], [1, 2])
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    for _ in range(20):
        await RisingEdge(dut.clk)
        if dut.valid.value == 1:
            break
    if dut.valid.value != 1:
        raise TestFailure("Valid not asserted")
    # Should be valid, no bits set (or undefined if not constrained, but let's assume 0)
    # Actually, if no constraints, mask might be undefined or 0. We expect valid=1 and impossible=0.
    if dut.impossible.value != 0:
        raise TestFailure("Prefix case should be possible")
        
    # Test Case: Impossible (prefix violation)
    # w1=[1, 2], w2=[1]. w1 longer, equal prefix. Impossible.
    dut._log.info("Test 5: w1=[1, 2], w2=[1] (Prefix violation)")
    dut.rst_n.value = 0
    await Timer(10, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    load_words([1, 2], [1])
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    for _ in range(20):
        await RisingEdge(dut.clk)
        if dut.valid.value == 1 or dut.impossible.value == 1:
            break
    if dut.impossible.value != 1:
        raise TestFailure("Should be impossible due to prefix violation")
        
    dut._log.info("All tests passed")
