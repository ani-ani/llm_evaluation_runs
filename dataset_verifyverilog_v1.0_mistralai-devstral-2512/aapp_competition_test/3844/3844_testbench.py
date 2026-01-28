import cocotb
from cocotb.triggers import Timer, RisingEdge, ClockCycles
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

# Constants
DATA_WIDTH = 17  # Card value width (max 131071)
CLK_NS = 10
MAX_CYCLES = 250000  # Large enough for sequential processing of 100k cards + scan

@cocotb.test(timeout_time=10, timeout_unit="s")
async def test_card_game(dut):
    """Test the card game logic."""
    
    # Setup clock
    if has_signal(dut, 'clk'):
        clock = Clock(dut.clk, CLK_NS, units='ns')
        cocotb.start_soon(clock.start())
    else:
        # Combinational logic assumed
        pass

    # Reset
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 0
        if has_signal(dut, 'start'): dut.start.value = 0
        if has_signal(dut, 'card_valid'): dut.card_valid.value = 0
        if has_signal(dut, 'card_done'): dut.card_done.value = 0
        await ClockCycles(dut.clk, 2) if has_signal(dut, 'clk') else Timer(20, units='ns')
        dut.rst_n.value = 1
        if has_signal(dut, 'clk'): await RisingEdge(dut.clk)
    else:
        await Timer(10, units='ns')

    # Test cases from prompt
    # Case 1: 3, [4, 5, 7] -> Conan (all odd counts: 1, 1, 1)
    test_cases = [
        ([4, 5, 7], 1, "Conan"),
        ([1, 1], 0, "Agasa"),
        ([1, 1, 1], 1, "Conan"),
        ([2, 2, 2], 1, "Conan"), # 3 counts is odd
        ([1, 1, 2, 2, 2], 1, "Conan"), # 1 is even, 2 is odd
        ([1, 2, 1, 2], 0, "Agasa"), # Both even
        ([100000, 100000, 100000, 1, 1], 1, "Conan"), # 100k is odd
        ([50096]*9 + [28505], 1, "Conan"), # 9 is odd
    ]

    for idx, (cards, expected_result, desc) in enumerate(test_cases):
        cocotb.log.info(f"Running Test {idx+1}: {desc}")
        
        # Start processing
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
        else:
            await Timer(10, units='ns')

        # Feed cards sequentially
        for card in cards:
            dut.card_in.value = clamp_to_width(card, DATA_WIDTH)
            dut.card_valid.value = 1
            if has_signal(dut, 'clk'): await RisingEdge(dut.clk)
            else: await Timer(CLK_NS, units='ns')
            
            dut.card_valid.value = 0
            if has_signal(dut, 'clk'): await RisingEdge(dut.clk)
            else: await Timer(CLK_NS, units='ns')

        # Signal end of input
        dut.card_done.value = 1
        if has_signal(dut, 'clk'): await RisingEdge(dut.clk)
        else: await Timer(CLK_NS, units='ns')
        dut.card_done.value = 0

        # Wait for result
        if has_signal(dut, 'done'):
            found_done = False
            for _ in range(300000):  # Allow time for scan
                if has_signal(dut, 'clk'): await RisingEdge(dut.clk)
                else: await Timer(CLK_NS, units='ns')
                
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    found_done = True
                    break
            
            if not found_done:
                raise TestFailure(f"Timeout waiting for 'done' in test {desc}")
        else:
            # No done signal (combinational), wait for stabilization
            if has_signal(dut, 'clk'): await RisingEdge(dut.clk)
            else: await Timer(100, units='ns')

        # Check result
        if not has_signal(dut, 'result'):
             raise TestFailure(f"Result signal not found")
             
        result_val = int(dut.result.value)
        if result_val != expected_result:
            raise TestFailure(f"Test '{desc}' failed: Expected {expected_result}, got {result_val}")
        
        cocotb.log.info(f"Test '{desc}' Passed")

        # Reset for next test if needed (simple approach: reset dut)
        if has_signal(dut, 'rst_n'):
            dut.rst_n.value = 0
            if has_signal(dut, 'clk'): await ClockCycles(dut.clk, 2)
            else: await Timer(20, units='ns')
            dut.rst_n.value = 1
            if has_signal(dut, 'clk'): await RisingEdge(dut.clk)
        else:
             await Timer(20, units='ns')
