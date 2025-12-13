import cocotb
from cocotb.triggers import Timer
from cocotb.types import LogicArray

@cocotb.test()
async def test_hanabi(dut):
    test_cases = [
        # (num_cards, [card_data], expected_hints)
        (2, [0b100_011, 0b100_011], 0),  # Input 1: G3 G3
        (4, [
            0b001_100,  # G4
            0b000_100,  # R4
            0b000_011,  # R3
            0b010_011   # B3
        ], 2),  # Input 2
        (5, [
            0b010_001,  # B1
            0b011_001,  # Y1
            0b100_001,  # W1
            0b001_001,  # G1
            0b000_001   # R1
        ], 4),  # Input 3
        (2, [0b100_011, 0b011_101], 1),  # W3 vs Y5
        (2, [0b100_101, 0b011_101], 1)   # W5 vs Y5
    ]

    passed = 0
    for (n, cards, expected) in test_cases:
        # Pack cards into 48-bit vector (pad with zeros if <8 cards)
        packed = 0
        for i, card in enumerate(cards):
            if i < 8:
                packed |= card << (6*i)
        
        dut.num_cards.value = n
        dut.cards.value = packed
        await Timer(1, units='ns')
        
        actual = dut.min_hints.value.integer
        if actual == expected:
            passed += 1
        else:
            dut._log.error(f"Failed: n={n}, cards={[bin(c) for c in cards]}
                Expected {expected}, got {actual}")
    
    total = len(test_cases)
    dut._log.info(f"{passed}/{total} tests passed")"