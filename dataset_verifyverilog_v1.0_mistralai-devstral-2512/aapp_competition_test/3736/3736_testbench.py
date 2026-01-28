import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Mandatory helpers
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

# Helper to set packed array or individual signals
def write_string(dut, s, max_len=16):
    # Convert string to ASCII list
    vals = [ord(c) for c in s]
    if has_signal(dut, 'char_data'):
        # Assuming char_data is a vector of 16*8 bits or an array
        # Check if it's a packed vector or unpacked array
        try:
            # Try treating as packed 128-bit vector
            packed = 0
            for i, v in enumerate(vals):
                packed |= (v & 0xFF) << (i * 8)
            dut.char_data.value = packed
            return
        except Exception:
            pass
        
        # Try treating as unpacked array (e.g., char_data[0], char_data[1]...)
        try:
            # Clear unused slots first (optional, but good practice)
            for i in range(max_len):
                if i < len(vals):
                    dut.char_data[i].value = vals[i]
                else:
                    dut.char_data[i].value = 0
            return
        except Exception:
            pass

    # Fallback: check for explicit individual ports like char_data_0
    port_found = False
    for i in range(max_len):
        port_name = f'char_data_{i}'
        if has_signal(dut, port_name):
            port_found = True
            if i < len(vals):
                getattr(dut, port_name).value = vals[i]
            else:
                getattr(dut, port_name).value = 0
    
    if not port_found:
        # Try accessing as an attribute list dut.char_data[i]
        try:
            base = getattr(dut, 'char_data')
            for i in range(max_len):
                if i < len(vals):
                    base[i].value = vals[i]
                else:
                    base[i].value = 0
        except AttributeError:
            # Last resort: if char_data doesn't exist, maybe inputs are direct?
            pass

async def wait_for_done(dut, max_cycles=100):
    for _ in range(max_cycles):
        if has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
        await RisingEdge(dut.clk)
    raise TestFailure(f"Timeout waiting for done signal after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): 
        if has_signal(dut, 'clk'): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    if has_signal(dut, 'clk'): await RisingEdge(dut.clk)

@cocotb.test(timeout_time=500, timeout_unit="ms")
async def test_mirror_word(dut):
    # Setup Clock
    CLK_NS = 10
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational circuit
        await Timer(10, units='ns')

    # Test Cases (String, Expected Result)
    # Expected: 1 (YES), 0 (NO)
    test_cases = [
        ("AHA", 1),
        ("Z", 0),
        ("XO", 0),
        ("AAA", 1),
        ("AHHA", 1),
        ("BAB", 0),
        ("OMMMAAMMMO", 1),
        ("YYHUIUGYI", 0),
        ("TT", 1),
        ("UUU", 1),
        ("WYYW", 1),
        ("MITIM", 1),
        ("VO", 0),
        ("WWS", 0),
        ("A", 1),
        ("B", 0),
        ("SSS", 0),
        ("I", 1),
        ("SS", 0),
        ("AAAAAABAAAAAA", 0)
    ]

    for s, expected in test_cases:
        cocotb.log.info(f"Testing string: '{s}' (Expected: {'YES' if expected else 'NO'})")
        
        # Write input
        write_string(dut, s)
        
        # Set length
        if has_signal(dut, 'len'):
            dut.len.value = len(s)
        
        # Trigger
        if has_signal(dut, 'start') and has_signal(dut, 'clk'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            await wait_for_done(dut)
        elif has_signal(dut, 'clk'):
            # No start signal, just wait for done or cycles
            await wait_for_done(dut)
        else:
            # Combinational, just wait a bit
            await Timer(50, units='ns')

        # Read result
        if not has_signal(dut, 'result'):
            raise TestFailure("Signal 'result' not found")
            
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result undefined for input '{s}'")
        
        result_val = int(dut.result.value)
        
        if result_val != expected:
            raise TestFailure(f"Input '{s}': Expected {expected}, got {result_val}")

    cocotb.log.info("All tests passed!")