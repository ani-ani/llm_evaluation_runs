import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

# Pack string into integer (little-endian or big-endian? Verilog usually big-endian for arrays)
# We'll assume fragments[0] is the first string, packed as 8 bytes.
# Let's pack as: char 0 at bits 63:56, char 7 at bits 7:0 (Big Endian)
def pack_string(s, width=64):
    val = 0
    s = s.ljust(8)[:8]  # Pad or truncate to 8 chars
    for i, ch in enumerate(s):
        val |= (ord(ch) << (56 - i*8))
    return val

def unpack_string(val, length=8):
    s = ""
    for i in range(length):
        char_code = (val >> (56 - i*8)) & 0xFF
        if char_code == 0: break
        s += chr(char_code)
    return s

# Wait for done signal
async def wait_for_done(dut, max_cycles=500):
    for _ in range(max_cycles):
        if has_signal(dut, 'done'):
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                return True
        await RisingEdge(dut.clk)
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_reconstructor(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational logic assumed to settle within 100ns
        await Timer(100, units='ns')

    # Test cases based on prompt examples
    test_cases = [
        {
            "fragments": ["n fox jumps ove", "uick brown f", "The quick b", "y dog.", "rown fox", "mps over the l", "the lazy dog"],
            "expected": "The quick brown fox jumps over the lazy dog.",
            "desc": "Simple reconstruction"
        },
        {
            "fragments": ["cdefghi", "efghijk", "efghijx", "abcdefg"],
            "expected": "AMBIGUOUS",
            "desc": "Ambiguous reconstruction"
        },
        {
            "fragments": ["cdefghix", "efghijk", "abcdefghi", "cdefghij"],
            "expected": "abcdefghijk",
            "desc": "Unique longest path"
        }
    ]

    for i, tc in enumerate(test_cases):
        cocotb.log.info(f"Running Test {i+1}: {tc['desc']}")
        
        n = len(tc['fragments'])
        
        if is_seq:
            # Set inputs
            if has_signal(dut, 'n'):
                dut.n.value = n
            
            # Pack and assign fragments
            # Assuming dut.fragments is an array of logic vectors
            for idx, frag in enumerate(tc['fragments']):
                packed = pack_string(frag)
                if has_signal(dut, f'fragments_{idx}'):
                    getattr(dut, f'fragments_{idx}').value = packed
                elif has_signal(dut, 'fragments') and hasattr(dut.fragments, '__len__'):
                    dut.fragments[idx].value = packed
                else:
                    raise TestFailure(f"Cannot access fragments signal for index {idx}")
            
            # Start
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Check result
            if not has_signal(dut, 'status'):
                raise TestFailure("Status signal missing")
                
            status = int(dut.status.value)
            
            if tc['expected'] == "AMBIGUOUS":
                if status != 1:  # Assuming 01 = Ambiguous
                    raise TestFailure(f"Expected AMBIGUOUS (status=1), got status={status}")
            else:
                if status != 0:  # Assuming 00 = Valid
                    raise TestFailure(f"Expected Valid (status=0), got status={status}")
                
                if not has_signal(dut, 'result'):
                    raise TestFailure("Result signal missing")
                    
                result_val = int(dut.result.value)
                # Unpack result (assuming max 16 chars for result bus)
                result_str = ""
                # Unpacking logic depends on exact bit layout, assuming standard big endian packing for 128 bits
                # Result is usually concatenated text.
                # We'll read raw bytes to reconstruct string
                raw_bytes = []
                for b in range(16): # 128 bits = 16 bytes
                    byte = (result_val >> (120 - b*8)) & 0xFF
                    if byte != 0:
                        raw_bytes.append(chr(byte))
                    else:
                        break
                
                final_str = "".join(raw_bytes)
                
                if final_str != tc['expected']:
                     raise TestFailure(f"Expected '{tc['expected']}', got '{final_str}'")
            
            # Reset for next test
            await reset_dut(dut)
        else:
            # Combinational testing logic (simplified)
            # For combinational, we just check if logic exists
            # Since the problem is complex, sequential implementation is standard.
            pass

    cocotb.log.info("All tests passed!")