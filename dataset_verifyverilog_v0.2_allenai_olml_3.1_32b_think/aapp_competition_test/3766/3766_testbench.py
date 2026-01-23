import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
import random

# Helper function to convert card string to 16-bit mask
def card_to_mask(card_str):
    color_map = {'R': 0, 'G': 1, 'B': 2, 'Y': 3, 'W': 4}
    value_map = {'1': 0, '2': 1, '3': 2, '4': 3, '5': 4}
    c = color_map[card_str[0]]
    v = value_map[card_str[1]]
    mask = (1 << c) | (1 << (v + 5))
    return mask

@cocotb.test()
async def test_hanabi_solver(dut):
    """Test Hanabi Solver module"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.unique_cards_count.value = 0
    for i in range(16):
        dut.card_attributes[i].value = 0
    
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        ("2
G3 G3", ["G3", "G3"]),
        ("4
G4 R4 R3 B3", ["G4", "R4", "R3", "B3"]),
        ("5
B1 Y1 W1 G1 R1", ["B1", "Y1", "W1", "G1", "R1"]),
        ("3
G4 G3 B4", ["G4", "G3", "B4"]),
        ("2
W3 Y5", ["W3", "Y5"]),
        ("2
W5 Y5", ["W5", "Y5"]) 
    ]
    
    for i, (desc, cards) in enumerate(test_cases):
        # Extract unique cards
        unique_cards = list(set(cards))
        count = len(unique_cards)
        
        # Load inputs
        dut.unique_cards_count.value = count
        for idx in range(16):
            if idx < count:
                dut.card_attributes[idx].value = card_to_mask(unique_cards[idx])
            else:
                dut.card_attributes[idx].value = 0
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (with timeout)
        cycles = 0
        while dut.done.value == 0 and cycles < 2000:
            await RisingEdge(dut.clk)
            cycles += 1
        
        # Calculate expected result
        # Brute force in Python to verify
        def solve_py(cards):
            masks = [card_to_mask(c) for c in cards]
            min_hints = 11
            # Iterate 0 to 1023
            for m in range(1024):
                valid = True
                for i in range(len(masks)):
                    for j in range(i+1, len(masks)):
                        # If distinguishable by mask
                        diff = masks[i] ^ masks[j]
                        if (m & diff) == 0:
                            valid = False
                            break
                    if not valid: break
                if valid:
                    popcount = bin(m).count('1')
                    if popcount < min_hints:
                        min_hints = popcount
            return min_hints
        
        expected = solve_py(unique_cards)
        observed = int(dut.min_hints.value)
        
        print(f"Test {i+1}: {desc}")
        print(f"  Cards: {unique_cards}")
        print(f"  Expected: {expected}, Observed: {observed}")
        
        assert observed == expected, f"Mismatch: {observed} != {expected}"
    
    print("All tests passed!")
