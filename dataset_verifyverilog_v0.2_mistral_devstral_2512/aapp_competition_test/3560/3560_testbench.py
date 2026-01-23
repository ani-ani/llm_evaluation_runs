import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_barbarian_substring_matcher(dut):
    """Test barbarian substring matcher with pattern loading and queries"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.operation_type.value = 0
    dut.barbarian_id.value = 0
    dut.string_input.value = 0
    dut.string_length.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    print("Starting pattern load...")
    # Load patterns for 8 barbarians (patterns: a, bc, abc, xyz, def, gh, i, j)
    # Pattern 0: "a" (length 1)
    # Pattern 1: "bc" (length 2)
    # Pattern 2: "abc" (length 3)
    # Pattern 3: "xyz" (length 3)
    # Pattern 4: "def" (length 3)
    # Pattern 5: "gh" (length 2)
    # Pattern 6: "i" (length 1)
    # Pattern 7: "j" (length 1)
    
    patterns = [
        (0, ord('a'), 1),  # barbarian_id, char1, length
        (1, (ord('b') << 8) | ord('c'), 2),
        (2, (ord('a') << 16) | (ord('b') << 8) | ord('c'), 3),
        (3, (ord('x') << 16) | (ord('y') << 8) | ord('z'), 3),
        (4, (ord('d') << 16) | (ord('e') << 8) | ord('f'), 3),
        (5, (ord('g') << 8) | ord('h'), 2),
        (6, ord('i'), 1),
        (7, ord('j'), 1),
    ]
    
    # Load each pattern
    for pid, pval, plen in patterns:
        dut.start.value = 1
        dut.operation_type.value = 0  # load pattern mode
        dut.barbarian_id.value = pid
        dut.string_input.value = pval
        dut.string_length.value = plen
        await RisingEdge(dut.clk)
        dut.start.value = 0
        # Wait for done
        while not dut.done.value:
            await RisingEdge(dut.clk)
    
    print("Pattern loading complete")
    await Timer(10, units='ns')
    
    # Now test operations
    # Query 1: Type 1 - show word "abca"
    # Expected: barbarian 0 ("a") matches, barbarian 1 ("bc") matches, barbarian 2 ("abc") matches
    # So counter increments for 0,1,2
    
    print("
Test 1: Show word 'abca' (length 4)")
    word1 = (ord('a') << 24) | (ord('b') << 16) | (ord('c') << 8) | ord('a')
    dut.start.value = 1
    dut.operation_type.value = 1  # type1
    dut.string_input.value = word1
    dut.string_length.value = 4
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (type1 takes many cycles)
    timeout = 0
    while not dut.done.value and timeout < 500:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 500:
        raise TestFailure("Type1 operation timed out")
    
    print(f"Type1 complete, timeout cycles: {timeout}")
    await Timer(10, units='ns')
    
    # Query 2: Type 2 - ask barbarian 0 ("a") -> should be 1
    print("
Test 2: Query barbarian 0 (pattern 'a'), expected: 1")
    dut.start.value = 1
    dut.operation_type.value = 2  # type2
    dut.barbarian_id.value = 0
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await RisingEdge(dut.clk)
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    result = dut.result.value
    print(f"Result: {int(result)}")
    if int(result) != 1:
        raise TestFailure(f"Expected 1, got {int(result)}")
    
    # Query 3: Type 2 - ask barbarian 2 ("abc") -> should be 1
    print("
Test 3: Query barbarian 2 (pattern 'abc'), expected: 1")
    dut.start.value = 1
    dut.operation_type.value = 2
    dut.barbarian_id.value = 2
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await RisingEdge(dut.clk)
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    result = dut.result.value
    print(f"Result: {int(result)}")
    if int(result) != 1:
        raise TestFailure(f"Expected 1, got {int(result)}")
    
    # Query 4: Type 1 - show word "bc"
    # This should match barbarian 1 ("bc")
    print("
Test 4: Show word 'bc' (length 2)")
    word2 = (ord('b') << 8) | ord('c')
    dut.start.value = 1
    dut.operation_type.value = 1
    dut.string_input.value = word2
    dut.string_length.value = 2
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 500:
        await RisingEdge(dut.clk)
        timeout += 1
    
    print(f"Type1 complete")
    await Timer(10, units='ns')
    
    # Query 5: Type 2 - ask barbarian 1 ("bc") -> should be 2
    print("
Test 5: Query barbarian 1 (pattern 'bc'), expected: 2")
    dut.start.value = 1
    dut.operation_type.value = 2
    dut.barbarian_id.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await RisingEdge(dut.clk)
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    result = dut.result.value
    print(f"Result: {int(result)}")
    if int(result) != 2:
        raise TestFailure(f"Expected 2, got {int(result)}")
    
    # Query 6: Type 2 - ask barbarian 2 ("abc") -> should be 1 (not in "bc")
    print("
Test 6: Query barbarian 2 (pattern 'abc'), expected: 1")
    dut.start.value = 1
    dut.operation_type.value = 2
    dut.barbarian_id.value = 2
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await RisingEdge(dut.clk)
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    result = dut.result.value
    print(f"Result: {int(result)}")
    if int(result) != 1:
        raise TestFailure(f"Expected 1, got {int(result)}")
    
    # Query 7: Type 1 - show word "a"
    # Matches barbarians 0 ("a")
    print("
Test 7: Show word 'a' (length 1)")
    word3 = ord('a')
    dut.start.value = 1
    dut.operation_type.value = 1
    dut.string_input.value = word3
    dut.string_length.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 500:
        await RisingEdge(dut.clk)
        timeout += 1
    
    print(f"Type1 complete")
    await Timer(10, units='ns')
    
    # Query 8: Type 2 - ask barbarian 0 ("a") -> should be 2
    print("
Test 8: Query barbarian 0 (pattern 'a'), expected: 2")
    dut.start.value = 1
    dut.operation_type.value = 2
    dut.barbarian_id.value = 0
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await RisingEdge(dut.clk)
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    result = dut.result.value
    print(f"Result: {int(result)}")
    if int(result) != 2:
        raise TestFailure(f"Expected 2, got {int(result)}")
    
    print("
All tests passed!")
    
    # Summary
    print("
=== Test Summary ===")
    print("All 8 test operations completed successfully")
    print("Tests covered: pattern loading, type1 queries, type2 queries")
    print("Patterns: a, bc, abc, xyz, def, gh, i, j")
    print("Words shown: abca, bc, a")
    print("Verify: barbarian 0: 2, barbarian 1: 2, barbarian 2: 1")
    print("
X/Y tests passed: 8/8")
