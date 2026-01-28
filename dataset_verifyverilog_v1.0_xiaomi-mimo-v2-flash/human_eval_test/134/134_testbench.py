import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
DATA_WIDTH = 8
ARRAY_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 100

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_string(dut, txt):
    # Pad with spaces or truncate to 16 bytes
    padded = (txt[:16] + ' ' * (16 - len(txt[:16])))[:16]
    bytes_list = [ord(c) for c in padded]
    
    # Set length
    actual_len = min(len(txt), 16)
    dut.len.value = clamp_to_width(actual_len, 4)
    
    # Set bytes
    for i in range(16):
        dut.char_in[i].value = clamp_to_width(bytes_list[i], 7)

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_check_last_char(dut):
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (input_string, expected_result)
    test_cases = [
        ("apple", 0),          # Ends with 'e', followed by nothing (start) -> True? Wait, logic says if i-1 < 0 -> True. But 'apple' has no spaces. 'e' is alphabetical. i-1 is 'l' (alphabetical) -> False.
        ("apple pi e", 1),     # Ends with 'e', followed by space -> True
        ("eeeee", 0),          # Ends with 'e', followed by 'e' -> False
        ("A", 1),              # Ends with 'A', followed by nothing -> True
        ("Pumpkin pie ", 0),   # Ends with space -> False
        ("Pumpkin pie 1", 0),  # Ends with '1' (not letter) -> False
        ("", 0),               # Empty -> False
        ("eeeee e ", 0),       # Ends with space -> False
        ("apple pie", 0),      # Ends with 'e', followed by 'p' -> False
        ("apple pi e ", 0),    # Ends with space -> False
        ("test ", 0),          # Ends with space -> False
        ("word a", 1),         # Ends with 'a', followed by space -> True
        ("word", 0),           # Ends with 'd', followed by 'r' -> False
        ("z", 1),              # Ends with 'z', followed by nothing -> True
    ]
    
    passed = 0
    failed = 0
    
    for i, (txt, exp) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: '{txt}' -> Expected {exp}")
        try:
            await write_string(dut, txt)
            
            # Trigger
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for result
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal is undefined")
            
            res = int(dut.result.value)
            if res != exp:
                raise TestFailure(f"Expected {exp}, got {res}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL (Case '{txt}'): {e}")
            failed += 1
        
        # Reset between tests
        await reset_dut(dut, cycles=1)
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {failed + passed}")
