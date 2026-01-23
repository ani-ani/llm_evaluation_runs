import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

# Helper to map chars to 4-bit values
CARD_MAP = {
    'A': 0, '2': 1, '3': 2, '4': 3, '5': 4, '6': 5, '7': 6, '8': 7, '9': 8, 
    'T': 9, 'J': 10, 'Q': 11, 'K': 12
}

def encode_deck(deck_str):
    # 52 cards -> 52 * 4 = 208 bits? No, prompt says 416 bit input.
    # Prompt says: "input [415:0] deck". 
    # "deck[415:412] is the first card"
    # If 52 cards * 4 bits = 208 bits. Why 416? Maybe 8 bits per card? 
    # Prompt says: "Card Representation: 4-bit values".
    # But 416 bits = 52 * 8. 
    # Let's re-read prompt carefully. 
    # "input [415:0] deck`: The shuffled deck. `deck[415:412]` is the first card"
    # This implies 4 bits per card. 416 bits is large. 
    # 52 cards * 4 bits = 208 bits. 
    # Maybe the prompt intended 208 bits but wrote 416? Or maybe 8 bits per char?
    # Given the text says "4-bit values", I will assume the prompt meant 208 bits but wrote 416 by mistake (208*2). 
    # OR, maybe the testbench should generate 208 bit vectors and the prompt width is just a suggestion.
    # Wait, if I strictly follow the prompt's 416 bits, I need to fill 416.
    # If 52 cards, and 416/52 = 8 bits per card.
    # BUT the prompt says "Card Representation: 4-bit values".
    # This is a conflict. 
    # Let's assume the prompt's bit width is wrong and 208 bits is correct, OR the prompt meant 8 bits per card.
    # Given 416 is specific, let's try to map to 8 bits per card, but only use lower 4 bits in logic? 
    # No, cleaner to fix the spec. 
    # Let's check the example Python code provided. It takes a string.
    # The Verilog prompt says `deck[415:412]` is first card.
    # If I use 8 bits per card (to match 416), `deck[415:408]` would be first card.
    # The prompt says `deck[415:412]` (4 bits). 
    # This is likely a typo in the prompt for 416. It should be 208.
    # However, I must output the prompt as requested. 
    # If I output "input [415:0] deck", the testbench must provide 416 bits.
    # If the logic expects 4 bits per card, but address is 4 bits wide, then 416 bits covers 104 slots.
    # 52 cards * 4 = 208 bits. 
    # I will modify the Verilog prompt's width to 208 to be consistent with "4-bit values" and "52 cards". 
    # Wait, the instructions say "Convert Python... into Verilog". The user provided the Python. 
    # The user didn't provide the prompt. I generate the prompt.
    # I will generate a prompt that is CORRECT. 
    # Correct width: 208 bits (52 * 4). 
    # I will ignore the `415:0` in the example reasoning and use 207:0.
    # Actually, looking at the prompt generation logic provided in the system message: "Always specify exact bit widths".
    # The Python input is a string of 52 chars.
    # I will generate a prompt with `input [207:0] deck`.
    # I will correct the `deck[415:412]` to `deck[207:204]`.
    # 
    # Re-reading the prompt I generated: "input [415:0] deck". 
    # I will correct this in the logic to 208 bits. 
    # BUT the user might be copy-pasting my prompt. 
    # Let's try to stick to the user's implied "416" if possible. 
    # 416 bits / 52 cards = 8 bits per card. 
    # If I use 8 bits per card, I can store the char ASCII? 
    # 'A' (65) to 'K' (75). 
    # '2' (50) to '9' (57). 'T' (84). 
    # This is messy for HDL. 
    # 4 bits is cleaner. 
    # I will assume the user made a mistake with 416 and 208 is correct. 
    # I will write the Verilog prompt assuming 208 bits, but I'll make the testbench flexible or just point out the fix.
    # 
    # Actually, I will stick to the prompt I wrote in the `prompt` field. 
    # If I wrote `input [415:0] deck`, I must generate 416 bits.
    # I will use 8 bits per card in the testbench, but map the lower 4 bits to the value.
    # Or just use 8 bits and ignore the logic mismatch. 
    # Better: I will modify the `prompt` I wrote to be correct (208 bits). 
    # I will correct the `prompt` text in the final output to use 208 bits. 
    # I will also correct the indexing `deck[415:412]` to `deck[207:204]`. 
    
    bits = []
    for char in deck_str:
        val = CARD_MAP[char]
        # 4 bits
        bits.append(f"{val:04b}")
    # Flatten
    full_bin = "".join(bits)
    return int(full_bin, 2)

@cocotb.test()
async def test_trash_game(dut):
    # Clock generation (if sequential)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Test cases
    test_cases = [
        {
            "input": "23456789TJ23456789TJA89Q66JK37T2A4AQK3AK5T8Q24K97JQ5",
            "expected": "Theta wins" 
        },
        {
            "input": "89724TJTA67K4J87Q8T6Q7J2324T558KA99A3KA356QJ6523QK49",
            "expected": "Theta wins"
        },
        {
            "input": "6Q4K476722745A9A9875A2TT3JA6K5K34JKQQTQ235T9868J893J",
            "expected": "Theta loses"
        }
    ]

    for i, tc in enumerate(test_cases):
        print(f"Running Test Case {i+1}...")
        
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        dut.deck.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

        # Load Deck
        # If prompt says 416 bits, we use 8 bits/char or padding. 
        # To be safe, let's assume my prompt uses 208 bits (corrected).
        deck_val = encode_deck(tc["input"])
        dut.deck.value = deck_val
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (with timeout)
        cycles = 0
        while not dut.done.value and cycles < 3000:
            await RisingEdge(dut.clk)
            cycles += 1
        
        # Check result
        assert dut.done.value == 1, "Simulation did not finish in time"
        
        result = "Theta wins" if dut.result.value else "Theta loses"
        print(f"Expected: {tc['expected']}, Got: {result}")
        assert result == tc["expected"], f"Test {i+1} Failed"

    print("All tests passed!")
