import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

@cocotb.test()
async def test_translator_matcher_basic(dut):
    """Test basic translator matching"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    # Test case 1: 6 translators, 5 languages - should find matching
    # Translators: [0,1], [0,2], [1,3], [2,3], [1,2], [4,3]
    # Expected pairs: (5,3), (1,0), (2,4) or any valid matching
    
    dut.num_translators.value = 6
    dut.num_languages.value = 5
    
    # Set language pairs for each translator
    lang1 = [0, 0, 1, 2, 1, 4]
    lang2 = [1, 2, 3, 3, 2, 3]
    
    for i in range(16):
        if i < 6:
            dut.translator_lang1[i].value = lang1[i]
            dut.translator_lang2[i].value = lang2[i]
        else:
            dut.translator_lang1[i].value = 0
            dut.translator_lang2[i].value = 0
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (max 1000 cycles for test)
    timeout = 1000
    for i in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    else:
        raise TestFailure("Timeout - did not complete")
    
    # Check results
    if dut.impossible.value:
        raise TestFailure("Should find matching for test case 1")
    
    if not dut.valid.value:
        raise TestFailure("Valid should be high when matching found")
    
    num_pairs = int(dut.num_pairs.value)
    if num_pairs != 3:
        raise TestFailure(f"Expected 3 pairs, got {num_pairs}")
    
    # Verify each pair shares a language
    for i in range(num_pairs):
        p1 = int(dut.pair1[i].value)
        p2 = int(dut.pair2[i].value)
        # Check they share a language
        l1_p1 = lang1[p1]
        l2_p1 = lang2[p1]
        l1_p2 = lang1[p2]
        l2_p2 = lang2[p2]
        
        shares_lang = (l1_p1 == l1_p2 or l1_p1 == l2_p2 or 
                       l2_p1 == l1_p2 or l2_p1 == l2_p2)
        
        if not shares_lang:
            raise TestFailure(f"Pair ({p1},{p2}) does not share a language")
    
    # Check all translators are paired
    paired = set()
    for i in range(num_pairs):
        p1 = int(dut.pair1[i].value)
        p2 = int(dut.pair2[i].value)
        paired.add(p1)
        paired.add(p2)
    
    if len(paired) != 6:
        raise TestFailure(f"Not all translators paired. Paired: {paired}")
    
    dut._log.info(f"Test 1 passed: Found {num_pairs} valid pairs")

@cocotb.test()
async def test_translator_matcher_impossible(dut):
    """Test impossible case: 3 translators (odd number)"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    # Test case 2: 3 translators - impossible (odd number)
    dut.num_translators.value = 3
    dut.num_languages.value = 3
    
    lang1 = [0, 1, 2]
    lang2 = [1, 2, 0]
    
    for i in range(16):
        if i < 3:
            dut.translator_lang1[i].value = lang1[i]
            dut.translator_lang2[i].value = lang2[i]
        else:
            dut.translator_lang1[i].value = 0
            dut.translator_lang2[i].value = 0
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    timeout = 1000
    for i in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    else:
        raise TestFailure("Timeout - did not complete")
    
    # Should be impossible
    if not dut.impossible.value:
        raise TestFailure("Should be impossible for 3 translators")
    
    if dut.valid.value:
        raise TestFailure("Valid should be low when impossible")
    
    dut._log.info("Test 2 passed: Correctly identified impossible case")

@cocotb.test()
async def test_translator_matcher_two_translators(dut):
    """Test simple case: 2 translators sharing a language"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    # 2 translators sharing language 0
    dut.num_translators.value = 2
    dut.num_languages.value = 2
    
    # Translator 0: [0,1], Translator 1: [0,2] - share language 0
    dut.translator_lang1[0].value = 0
    dut.translator_lang2[0].value = 1
    dut.translator_lang1[1].value = 0
    dut.translator_lang2[1].value = 2
    
    # Fill rest with zeros
    for i in range(2, 16):
        dut.translator_lang1[i].value = 0
        dut.translator_lang2[i].value = 0
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait
    timeout = 1000
    for i in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    else:
        raise TestFailure("Timeout")
    
    if dut.impossible.value:
        raise TestFailure("Should find matching for 2 translators")
    
    if not dut.valid.value:
        raise TestFailure("Valid should be high")
    
    if int(dut.num_pairs.value) != 1:
        raise TestFailure("Should have 1 pair")
    
    # Check pair is (0,1)
    p1 = int(dut.pair1[0].value)
    p2 = int(dut.pair2[0].value)
    
    if not ((p1 == 0 and p2 == 1) or (p1 == 1 and p2 == 0)):
        raise TestFailure(f"Expected pair (0,1) or (1,0), got ({p1},{p2})")
    
    dut._log.info("Test 3 passed: 2 translator case works")

@cocotb.test()
async def test_translator_matcher_four_translators(dut):
    """Test 4 translators: two possible pairs"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    # 4 translators: T0:[0,1], T1:[0,2], T2:[1,3], T3:[2,3]
    # T0-T1 (share 0), T2-T3 (share 3) OR T0-T2 (share 1), T1-T3 (share 2)
    dut.num_translators.value = 4
    dut.num_languages.value = 4
    
    dut.translator_lang1[0].value = 0
    dut.translator_lang2[0].value = 1
    dut.translator_lang1[1].value = 0
    dut.translator_lang2[1].value = 2
    dut.translator_lang1[2].value = 1
    dut.translator_lang2[2].value = 3
    dut.translator_lang1[3].value = 2
    dut.translator_lang2[3].value = 3
    
    for i in range(4, 16):
        dut.translator_lang1[i].value = 0
        dut.translator_lang2[i].value = 0
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait
    timeout = 1000
    for i in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    else:
        raise TestFailure("Timeout")
    
    if dut.impossible.value:
        raise TestFailure("Should find matching for 4 translators")
    
    if not dut.valid.value:
        raise TestFailure("Valid should be high")
    
    num_pairs = int(dut.num_pairs.value)
    if num_pairs != 2:
        raise TestFailure(f"Expected 2 pairs, got {num_pairs}")
    
    # Verify all paired
    paired = set()
    for i in range(num_pairs):
        p1 = int(dut.pair1[i].value)
        p2 = int(dut.pair2[i].value)
        paired.add(p1)
        paired.add(p2)
        # Check share language
        l1_p1 = [0,1][0] if p1==0 else [0,2][0] if p1==1 else [1,3][0] if p1==2 else [2,3][0]
        l2_p1 = [0,1][1] if p1==0 else [0,2][1] if p1==1 else [1,3][1] if p1==2 else [2,3][1]
        l1_p2 = [0,1][0] if p2==0 else [0,2][0] if p2==1 else [1,3][0] if p2==2 else [2,3][0]
        l2_p2 = [0,1][1] if p2==0 else [0,2][1] if p2==1 else [1,3][1] if p2==2 else [2,3][1]
        shares = (l1_p1 == l1_p2 or l1_p1 == l2_p2 or l2_p1 == l1_p2 or l2_p1 == l2_p2)
        if not shares:
            raise TestFailure(f"Pair ({p1},{p2}) don't share language")
    
    if len(paired) != 4:
        raise TestFailure(f"Not all paired: {paired}")
    
    dut._log.info(f"Test 4 passed: Found {num_pairs} valid pairs")

@cocotb.test()
async def test_translator_matcher_all_same_language(dut):
    """Test case where all translators share a common language"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    # 6 translators all sharing language 0
    dut.num_translators.value = 6
    dut.num_languages.value = 4
    
    lang1 = [0, 0, 0, 0, 0, 0]
    lang2 = [1, 2, 3, 1, 2, 3]
    
    for i in range(16):
        if i < 6:
            dut.translator_lang1[i].value = lang1[i]
            dut.translator_lang2[i].value = lang2[i]
        else:
            dut.translator_lang1[i].value = 0
            dut.translator_lang2[i].value = 0
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait
    timeout = 1000
    for i in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    else:
        raise TestFailure("Timeout")
    
    if dut.impossible.value:
        raise TestFailure("Should find matching - all share language 0")
    
    if not dut.valid.value:
        raise TestFailure("Valid should be high")
    
    num_pairs = int(dut.num_pairs.value)
    if num_pairs != 3:
        raise TestFailure(f"Expected 3 pairs, got {num_pairs}")
    
    # Verify all share language 0
    for i in range(num_pairs):
        p1 = int(dut.pair1[i].value)
        p2 = int(dut.pair2[i].value)
        # Both have lang1=0
        if dut.translator_lang1[p1].value != 0 or dut.translator_lang1[p2].value != 0:
            raise TestFailure(f"Pair ({p1},{p2}) don't both have language 0")
    
    dut._log.info(f"Test 5 passed: All share common language")

@cocotb.test()
async def test_translator_matcher_no_shared_language(dut):
    """Test case where no pairs share a language (impossible)"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    # 4 translators: T0:[0,1], T1:[2,3], T2:[0,4], T3:[2,5]
    # No two share a language
    dut.num_translators.value = 4
    dut.num_languages.value = 6
    
    dut.translator_lang1[0].value = 0
    dut.translator_lang2[0].value = 1
    dut.translator_lang1[1].value = 2
    dut.translator_lang2[1].value = 3
    dut.translator_lang1[2].value = 0
    dut.translator_lang2[2].value = 4
    dut.translator_lang1[3].value = 2
    dut.translator_lang2[3].value = 5
    
    for i in range(4, 16):
        dut.translator_lang1[i].value = 0
        dut.translator_lang2[i].value = 0
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait
    timeout = 1000
    for i in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    else:
        raise TestFailure("Timeout")
    
    # Should be impossible
    if not dut.impossible.value:
        raise TestFailure("Should be impossible - no pairs share language")
    
    if dut.valid.value:
        raise TestFailure("Valid should be low when impossible")
    
    dut._log.info("Test 6 passed: No shared language case correctly impossible")

@cocotb.test()
async def test_translator_matcher_run_all_tests(dut):
    """Summary: Run all test cases and print results"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # List of test cases: (num_t, num_l, lang1, lang2, should_work)
    test_cases = [
        (6, 5, [0,0,1,2,1,4], [1,2,3,3,2,3], True),  # Original sample
        (3, 3, [0,1,2], [1,2,0], False),  # Odd number
        (2, 2, [0,0], [1,2], True),  # Simple pair
        (4, 4, [0,0,1,2], [1,2,3,3], True),  # 4 translators
        (6, 4, [0,0,0,0,0,0], [1,2,3,1,2,3], True),  # All share language 0
        (4, 6, [0,2,0,2], [1,3,4,5], False),  # No shared pairs
    ]
    
    passed = 0
    total = len(test_cases)
    
    for idx, (num_t, num_l, l1, l2, should_work) in enumerate(test_cases):
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await Timer(20, units='ns')
        dut.rst_n.value = 1
        await Timer(20, units='ns')
        
        # Setup
        dut.num_translators.value = num_t
        dut.num_languages.value = num_l
        
        for i in range(16):
            if i < num_t:
                dut.translator_lang1[i].value = l1[i]
                dut.translator_lang2[i].value = l2[i]
            else:
                dut.translator_lang1[i].value = 0
                dut.translator_lang2[i].value = 0
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait
        timeout = 2000
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value:
                break
        else:
            continue  # timeout, fail
        
        # Verify
        success = False
        if should_work:
            if dut.valid.value and not dut.impossible.value:
                # Check pairing
                num_p = int(dut.num_pairs.value)
                if num_p == num_t // 2:
                    paired = set()
                    valid_pairs = True
                    for i in range(num_p):
                        p1 = int(dut.pair1[i].value)
                        p2 = int(dut.pair2[i].value)
                        if p1 == p2 or p1 >= num_t or p2 >= num_t:
                            valid_pairs = False
                            break
                        paired.add(p1)
                        paired.add(p2)
                    if len(paired) == num_t and valid_pairs:
                        success = True
        else:
            if dut.impossible.value and not dut.valid.value:
                success = True
        
        if success:
            passed += 1
            dut._log.info(f"Test {idx}: PASS")
        else:
            dut._log.error(f"Test {idx}: FAIL")
    
    dut._log.info(f"
{'='*50}")
    dut._log.info(f"FINAL SUMMARY: {passed}/{total} tests passed")
    dut._log.info(f"{'='*50}
")
    
    if passed < total:
        raise TestFailure(f"Only {passed}/{total} tests passed")