import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
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

# Convert ASCII string to 16-byte array for input
def str_to_bytearray(s, max_len=16):
    b = [0] * max_len
    for i, ch in enumerate(s[:max_len]):
        b[i] = ord(ch)
    return b

# Convert byte array back to string
def bytearray_to_str(b):
    s = ''
    for byte in b:
        if byte == 0:
            break
        s += chr(byte)
    return s

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_cryptarithm(dut):
    # Setup clock if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        CLK_NS = 10
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        # Reset
        dut.rst_n.value = 0
        if has_signal(dut, 'start'): dut.start.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        # Combinational - just wait for output
        await Timer(10, units='ns')

    test_cases = [
        ("SEND+MORE=MONEY", "9567+1085=10652"),
        ("A+A=A", "impossible"),
        ("C+B=A", "2+1=3")
    ]

    passed = 0
    failed = 0

    for i, (puzzle, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {puzzle}")
        try:
            # Setup input
            input_bytes = str_to_bytearray(puzzle, 16)
            if has_signal(dut, 'puzzle_str'):
                # Handle as array of signals or packed
                if 'puzzle_str' in str(dut._submodules):
                    for idx, val in enumerate(input_bytes):
                        dut.puzzle_str[idx].value = val
                else:
                    # Assume individual signals puzzle_str_0, puzzle_str_1...
                    for idx in range(16):
                        sig_name = f'puzzle_str_{idx}'
                        if has_signal(dut, sig_name):
                            getattr(dut, sig_name).value = input_bytes[idx]
            
            if has_signal(dut, 'puzzle_len'):
                dut.puzzle_len.value = len(puzzle)

            if is_seq:
                # Start processing
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                max_cycles = 1024
                done = False
                for _ in range(max_cycles):
                    await RisingEdge(dut.clk)
                    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                        done = True
                        break
                
                if not done:
                    raise TestFailure(f"Timeout waiting for done signal")
            else:
                # Combinational, just wait a bit
                await Timer(100, units='ns')

            # Read result
            if not has_signal(dut, 'result_str'):
                raise TestFailure("Missing result_str signal")

            result_bytes = []
            for idx in range(16):
                sig_name = f'result_str_{idx}' if has_signal(dut, 'result_str_0') else None
                if sig_name and has_signal(dut, sig_name):
                    val = int(getattr(dut, sig_name).value)
                else:
                    val = int(dut.result_str[idx].value)
                result_bytes.append(val)
            
            result_str = bytearray_to_str(result_bytes)
            
            # Check solved flag
            solved = 0
            if has_signal(dut, 'solved'):
                solved = int(dut.solved.value)
            
            # Validate
            if expected == "impossible":
                if solved != 0:
                    raise TestFailure(f"Expected impossible (solved=0), got solved={solved}")
                # Result string might be unchanged or empty
                cocotb.log.info(f"  Result (expected impossible): {result_str}")
            else:
                if solved != 1:
                    raise TestFailure(f"Expected solved=1, got solved={solved}")
                if result_str != expected:
                    raise TestFailure(f"Expected '{expected}', got '{result_str}'")
            
            passed += 1

        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1

    if failed > 0:
        raise TestFailure(f"{failed} tests failed")