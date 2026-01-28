import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH, ARRAY_SIZE, CLK_NS, MAX_CYCLES = 8, 5, 10, 200

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

def pack_string(s):
    """Pack ASCII string into 128-bit value (16 bytes)"""
    result = 0
    for i, ch in enumerate(s[:16]):
        if ord(ch) > 255:
            raise ValueError(f"Character '{ch}' out of range")
        result |= (ord(ch) << (i * 8))
    return result

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_parse_music(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        ("", 0, "empty string"),
        ("o o o o", 4, "four whole notes"),
        (".| .| .| .|", 4, "four quarter notes"),
        ("o| o| .| .| o o o o", 8, "mixed notes"),
        ("o| .| o| .| o o| o o|", 8, "complex sequence"),
        ("o", 1, "single whole note"),
        (".|", 1, "single quarter note"),
        ("o|", 1, "single half note")
    ]
    
    expected_results = {
        0: [],
        1: [4, 4, 4, 4],
        2: [1, 1, 1, 1],
        3: [2, 2, 1, 1, 4, 4, 4, 4],
        4: [2, 1, 2, 1, 4, 2, 4, 2],
        5: [4],
        6: [1],
        7: [2]
    }
    
    for i, (test_str, exp_count, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Convert string to 128-bit value
            str_val = pack_string(test_str)
            dut.str_in.value = str_val
            dut.str_len.value = len(test_str)
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            await wait_for_done(dut)
            
            # Read note count
            if not is_value_defined(dut.note_count.value):
                raise TestFailure("note_count undefined")
            note_count = int(dut.note_count.value)
            
            if note_count != exp_count:
                raise TestFailure(f"Expected {exp_count} notes, got {note_count}")
            
            # Read results (if any)
            if note_count > 0:
                results = []
                # The result is packed as 5x16-bit values in result[79:0]
                # Each note duration is in bits 3:0 of each 16-bit chunk
                for n in range(min(note_count, 5)):
                    # Extract bits (n*16) to (n*16+3)
                    shift = n * 16
                    duration = (int(dut.result.value) >> shift) & 0xF
                    results.append(duration)
                
                exp_results = expected_results.get(i, [])
                if results[:exp_count] != exp_results[:exp_count]:
                    raise TestFailure(f"Expected {exp_results[:exp_count]}, got {results[:exp_count]}")
            
            cocotb.log.info(f"PASS: {desc} -> {note_count} notes")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {desc} - {e}")
            raise
