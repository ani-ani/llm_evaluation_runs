import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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

# ASCII constants
ASCII_A = 65
ASCII_Z = 90
ASCII_a = 97
ASCII_z = 122
ASCII_0 = 48
ASCII_9 = 57

def str_to_bytes(s, max_len=16):
    """Convert string to list of bytes, pad with 0."""
    b = [ord(c) for c in s]
    if len(b) > max_len:
        b = b[:max_len]
    else:
        b.extend([0] * (max_len - len(b)))
    return b

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

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_check_dict_case(dut):
    # Setup clock
    clk_period = 10  # ns
    cocotb.start_soon(Clock(dut.clk, clk_period, units='ns').start())
    await reset_dut(dut)

    # Test cases: (keys_list, expected_all_lower, expected_all_upper, expected_valid, description)
    test_cases = [
        (["p", "b"], True, False, True, "Lowercase keys"),
        (["p", "A", "B"], False, False, False, "Mixed case keys"),
        (["p", "5", "a"], False, False, False, "Key with digit (non-alpha)"),
        (["Name", "Age", "City"], False, False, False, "Mixed case capitalized"),
        (["STATE", "ZIP"], False, True, True, "Uppercase keys"),
        (["fruit", "taste"], True, False, True, "More lowercase"),
        ([], False, False, False, "Empty dictionary"),
        (["HELLO", "WORLD", "!"] , False, False, False, "Uppercase with non-alpha"),
        (["a", "B", "c", "D"], False, False, False, "Alternating case")
    ]

    for i, (keys, exp_lower, exp_upper, exp_valid, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        
        # Setup inputs
        num_keys = len(keys)
        dut.num_pairs.value = num_keys
        
        # Clear keys array (max 8 keys, 16 chars)
        # Assuming interface is `keys[i][j]`
        MAX_KEYS = 8
        MAX_CHARS = 16
        
        for k_idx in range(MAX_KEYS):
            char_bytes = [0] * MAX_CHARS
            if k_idx < num_keys:
                key_str = keys[k_idx]
                # Check if key is integer (invalid type in python dict case, mapped to invalid here)
                if isinstance(key_str, int):
                    # Use a special non-alpha byte pattern to simulate invalid key
                    # But for Verilog, we just load the byte array with values
                    pass
                else:
                    char_bytes = str_to_bytes(key_str, MAX_CHARS)
            
            for c_idx in range(MAX_CHARS):
                # Assign to dut.keys[k_idx][c_idx]
                # Handle potential unpacked array access
                if has_signal(dut, 'keys'):
                    dut.keys[k_idx][c_idx].value = clamp_to_width(char_bytes[c_idx], 8)
                else:
                    # Fallback for flattened names if needed, though 2D array is standard
                    pass

        # Start the operation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut)
        
        # Check results
        res_valid = int(dut.valid.value) if is_value_defined(dut.valid.value) else 0
        res_lower = int(dut.all_lower.value) if is_value_defined(dut.all_lower.value) else 0
        res_upper = int(dut.all_upper.value) if is_value_defined(dut.all_upper.value) else 0
        
        # Convert to boolean for comparison
        res_valid_bool = res_valid == 1
        res_lower_bool = res_lower == 1
        res_upper_bool = res_upper == 1
        
        if res_valid_bool != exp_valid:
            raise TestFailure(f"Test '{desc}': Valid mismatch. Expected {exp_valid}, got {res_valid_bool}")
        if res_valid_bool:
            if res_lower_bool != exp_lower:
                raise TestFailure(f"Test '{desc}': All Lower mismatch. Expected {exp_lower}, got {res_lower_bool}")
            if res_upper_bool != exp_upper:
                raise TestFailure(f"Test '{desc}': All Upper mismatch. Expected {exp_upper}, got {res_upper_bool}")
        
        await RisingEdge(dut.clk)
        
    # Add a small delay after all tests
    await Timer(100, units='ns')