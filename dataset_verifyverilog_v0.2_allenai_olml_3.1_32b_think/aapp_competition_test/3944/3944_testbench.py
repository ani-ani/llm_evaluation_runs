import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_card_game(dut):
    """ Test the Card Game for Three logic with scaled inputs (8 cards max). """
    # Create a clock (10ns period)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Helper to set deck
    def set_deck(prefix, deck_list, length):
        # Pad to 8 elements if needed
        full_deck = deck_list + [0]*(8-len(deck_list))
        # Map chars to ints: 'a'=0, 'b'=1, 'c'=2
        mapping = {'a':0, 'b':1, 'c':2}
        for i, char in enumerate(full_deck):
            getattr(dut, f"{prefix}_deck_{i}").value = mapping.get(char, 0)
        getattr(dut, f"len_{prefix}").value = length

    # Test Case 1: 1 1 1 (Sample Input)
    # Alice: ['a'], Bob: ['b'], Charlie: ['c'] -> Should be 1? 
    # Wait, let's check the manual logic from prompt:
    # Prompt says: If Alice is a -> win (9 patterns). 
    # This test case specifically: N=1, M=1, K=1.
    # We need to verify the specific patterns mentioned.
    # Pattern 1: Alice='a'. (Any B, C). Alice wins immediately on her turn.
    # Pattern 2: Alice='b', Bob='a'. Alice plays 'b' -> Bob plays 'a' -> Alice wins.
    # Pattern 3: Alice='c', Charlie='a'. Alice plays 'c' -> Charlie plays 'a' -> Alice wins.
    
    # Let's test: Alice='a', Bob='b', Charlie='c'
    set_deck('a', ['a'], 1)
    set_deck('b', ['b'], 1)
    set_deck('c', ['c'], 1)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    if dut.result.value != 1:
        raise TestFailure(f"Test Case 1 Failed: Expected Alice win (1), got {dut.result.value}")
    print("Test 1 Passed: Alice wins immediately (card 'a')")

    # Reset for next test
    await FallingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 2: Alice='b', Bob='a', Charlie='c'
    set_deck('a', ['b'], 1)
    set_deck('b', ['a'], 1)
    set_deck('c', ['c'], 1)

    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    # Logic: A plays 'b' -> B plays 'a' -> A wins
    if dut.result.value != 1:
        raise TestFailure(f"Test Case 2 Failed: Expected Alice win (1), got {dut.result.value}")
    print("Test 2 Passed: Alice wins (A:b -> B:a -> A wins)")

    # Reset
    await FallingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 3: Alice='b', Bob='c', Charlie='a'
    set_deck('a', ['b'], 1)
    set_deck('b', ['c'], 1)
    set_deck('c', ['a'], 1)

    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    while not dut.done.value:
        await RisingEdge(dut.clk)

    # Logic: A plays 'b' -> B plays 'c' -> C plays 'a' -> A wins
    if dut.result.value != 1:
        raise TestFailure(f"Test Case 3 Failed: Expected Alice win (1), got {dut.result.value}")
    print("Test 3 Passed: Alice wins (A:b -> B:c -> C:a -> A wins)")

    # Reset
    await FallingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 4: Alice='c', Charlie='a'
    set_deck('a', ['c'], 1)
    set_deck('b', ['b'], 1) # Doesn't matter for this path
    set_deck('c', ['a'], 1)

    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    while not dut.done.value:
        await RisingEdge(dut.clk)

    # Logic: A plays 'c' -> C plays 'a' -> A wins
    if dut.result.value != 1:
        raise TestFailure(f"Test Case 4 Failed: Expected Alice win (1), got {dut.result.value}")
    print("Test 4 Passed: Alice wins (A:c -> C:a -> A wins)")

    # Reset
    await FallingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 5: Alice='c', Charlie='b', Bob='a'
    set_deck('a', ['c'], 1)
    set_deck('b', ['a'], 1)
    set_deck('c', ['b'], 1)

    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    while not dut.done.value:
        await RisingEdge(dut.clk)

    # Logic: A plays 'c' -> C plays 'b' -> B plays 'a' -> A wins
    if dut.result.value != 1:
        raise TestFailure(f"Test Case 5 Failed: Expected Alice win (1), got {dut.result.value}")
    print("Test 5 Passed: Alice wins (A:c -> C:b -> B:a -> A wins)")

    # Test Case 6: Alice loses (e.g., A=b, B=c, C=c)
    await FallingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    set_deck('a', ['b'], 1)
    set_deck('b', ['c'], 1)
    set_deck('c', ['c'], 1)

    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    while not dut.done.value:
        await RisingEdge(dut.clk)

    # Logic: A plays 'b' -> B plays 'c' -> C plays 'c' -> C wins
    if dut.result.value != 0:
        raise TestFailure(f"Test Case 6 Failed: Expected Alice loss (0), got {dut.result.value}")
    print("Test 6 Passed: Alice loses (Loop ends at Charlie)")

    print("All 6 tests passed!")
