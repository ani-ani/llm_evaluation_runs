import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except (ValueError, TypeError): return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, int(v)))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

# Card codes mapping (4-bit): 0=2,1=3,...,9=T,10=J,11=Q,12=K,13=A
card_map = {'2':0, '3':1, '4':2, '5':3, '6':4, '7':5, '8':6, '9':7, 'T':8, 'J':9, 'Q':10, 'K':11, 'A':12}
# Adjusted for 0-9 slots: A=12->0, 2=0->1, 3=1->2, ..., T=8->9, J=9->10
# Actually: A is slot 0, 2->1, 3->2, 4->3, 5->4, 6->5, 7->6, 8->7, 9->8, T->9
# So card code c maps to slot: if c==12 (A) -> 0, if c==0..8 -> c+1, if c==9 (T) -> 9, if c==10 (J) wildcard

async def write_deck(dut, deck_str):
    """Write deck string to 52x4-bit array"""
    deck_vals = []
    for ch in deck_str.strip():
        if ch in card_map:
            deck_vals.append(card_map[ch])
        else:
            deck_vals.append(0)  # default
    
    # Assuming dut has deck array or individual signals
    if has_signal(dut, 'deck') and hasattr(dut.deck, '__getitem__'):
        for i, v in enumerate(deck_vals):
            dut.deck[i].value = clamp_to_width(v, 4)
    else:
        # Fallback: try deck_0, deck_1, etc.
        for i in range(52):
            val = deck_vals[i] if i < len(deck_vals) else 0
            sig_name = f'deck_{i}'
            if has_signal(dut, sig_name):
                getattr(dut, sig_name).value = clamp_to_width(val, 4)

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=60):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=100, timeout_unit="ms")
async def test_trash_game(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    # Test cases
    test_cases = [
        ("23456789TJ23456789TJA89Q66JK37T2A4AQK3AK5T8Q24K97JQ5", "Theta wins"),
        ("89724TJTA67K4J87Q8T6Q7J2324T558KA99A3KA356QJ6523QK49", "Theta wins"),
        ("6Q4K476722745A9A9875A2TT3JA6K5K34JKQQTQ235T9868J893J", "Theta loses")
    ]
    
    for idx, (deck_str, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {idx+1}: Deck={deck_str}")
        await reset_dut(dut)
        await write_deck(dut, deck_str)
        
        # Start simulation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut, max_cycles=60)
        
        # Check result
        if not is_value_defined(dut.result.value):
            raise TestFailure("Result signal undefined")
        
        result_val = int(dut.result.value)
        # Map result: 0=Theta wins, 1=Friend wins
        if result_val == 0:
            actual = "Theta wins"
        elif result_val == 1:
            actual = "Theta loses"
        else:
            actual = "Invalid"
        
        if actual != expected:
            raise TestFailure(f"Expected {expected}, got {actual}")
        
        cocotb.log.info(f"Test {idx+1} passed")
