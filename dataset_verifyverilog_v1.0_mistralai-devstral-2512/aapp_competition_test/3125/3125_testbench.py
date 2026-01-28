import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers from prompt
DATA_WIDTH = 8
ARRAY_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 2000

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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_encoding_solver(dut):
    # Setup Clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)

    # Test Cases
    # I = input string, O = output string, exp = list of expected (plus, minus) tuples
    # Strings are padded to 16 chars with nulls or spaces for this simulation
    test_cases = [
        {
            "i_str": "a+b-c",
            "o_str": "a-b+d-c",
            "exp": [("-", "+d-")]
        },
        {
            "i_str": "knuth-morris-pratt",
            "o_str": "knuthmorrispratt",
            "exp": [("<any>", "<empty>")]
        }
    ]

    for tc in test_cases:
        i_str_val = tc["i_str"]
        o_str_val = tc["o_str"]
        
        # Convert strings to byte lists
        i_bytes = [ord(c) for c in i_str_val] + [0] * (16 - len(i_str_val))
        o_bytes = [ord(c) for c in o_str_val] + [0] * (16 - len(o_str_val))

        # Write strings to DUT (element-wise)
        dut.i_len.value = len(i_str_val)
        dut.o_len.value = len(o_str_val)
        
        for k in range(16):
            dut.i_str[k].value = i_bytes[k]
            dut.o_str[k].value = o_bytes[k]

        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for done
        await wait_for_done(dut, max_cycles=MAX_CYCLES)

        # Check Status
        status = int(dut.status.value)
        if status == 3: # Corrupted
            # Check if corruption was expected (unlikely for these tests)
            raise TestFailure(f"DUT returned corrupted status for input {i_str_val}")
        elif status == 2: # Found
            # Check result validity
            if not is_value_defined(dut.valid_out.value) or int(dut.valid_out.value) != 1:
                raise TestFailure("DUT claimed found (status=2) but valid_out is not 1")
            
            # Retrieve results (Simulating conversion from 128-bit vector to string)
            # In real verilog, this would be bit slicing. Here we extract int values
            # Note: The DUT might output multiple results sequentially or a single best match.
            # For this benchmark, we assume the DUT provides a valid solution.
            
            # We verify that the output matches ONE of the expected pairs
            found_match = False
            
            # Extract Plus
            plus_val = int(dut.result_plus.value)
            # Extract Minus
            minus_val = int(dut.result_minus.value)
            
            # Convert integers back to strings (handling the <any> and <empty> tokens)
            # Since Verilog outputs bytes, we map them. 
            # However, the spec allows <any> and <empty>. 
            # We need to define how the Verilog encodes these. 
            # Let's assume <empty> is all zeros and <any> is a specific pattern (e.g. 0xFF... or flagged)
            # For the sake of the test, we'll check the byte sequence.
            
            def bytes_to_string(b):
                if b == 0: return "<empty>"
                # Logic to decode bytes from integer b
                s = ""
                temp = b
                for _ in range(16):
                    char_code = temp & 0xFF
                    if char_code == 0: break
                    s += chr(char_code)
                    temp >>= 8
                return s

            # Note: The prompt allows <any>. We'll interpret a result of all 1s (0xFF...) as <any>
            # or we check if the DUT implementation handles it. 
            # Since this is a simulation, let's check if the output string matches expectation.
            
            # Let's simply check if the output bytes form the expected strings
            # We need to be careful with <any>.
            
            # Let's just log the output for manual verification in this complex case,
            # or implement a simple check. 
            
            # For the benchmark, we primarily care that the FSM runs and produces a result.
            # We will check the status code.
            
            # Actually, to be robust, let's convert the output bits to string
            def bits_to_str(bits_val):
                s = ""
                for k in range(16):
                    char = (bits_val >> (k*8)) & 0xFF
                    if char == 0: break
                    s += chr(char)
                return s if s else "<empty>"

            # Check for <any> handling. If the DUT returns all 1s for a field, we treat it as <any>
            # Define <any> mask (e.g. all 1s)
            ANY_MASK = (1 << 128) - 1
            
            res_p_str = "<any>" if plus_val == ANY_MASK else bits_to_str(plus_val)
            res_m_str = "<any>" if minus_val == ANY_MASK else bits_to_str(minus_val)
            
            for exp_p, exp_m in tc["exp"]:
                if res_p_str == exp_p and res_m_str == exp_m:
                    found_match = True
                    break
            
            if not found_match:
                raise TestFailure(f"Result ({res_p_str}, {res_m_str}) did not match any expected pair in {tc['exp']}")
            
            cocotb.log.info(f"Success: Input '{i_str_val}' -> Output '{o_str_val}' produced ({res_p_str}, {res_m_str})")
        else:
            raise TestFailure(f"Unexpected status {status}")