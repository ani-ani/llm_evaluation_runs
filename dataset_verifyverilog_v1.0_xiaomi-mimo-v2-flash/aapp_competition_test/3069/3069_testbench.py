import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

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
async def test_bracket_validity(dut):
    # Setup
    CLK_NS = 10
    MAX_CYCLES = 256
    MAX_LEN = 16
    
    # Check for required signals
    if not (has_signal(dut, 'clk') and has_signal(dut, 'rst_n') and has_signal(dut, 'start')):
        raise TestFailure("Required signals (clk, rst_n, start) missing")

    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases
    test_cases = [
        ("()))", True),  # Can be inverted to ()() or (())
        (")))(", False), # Impossible
        ("()", True),    # Already valid
        ("((", False),   # Impossible (balance never 0)
        ("))", False),   # Impossible (balance negative)
        ("())(", True),  # Can be inverted
    ]

    passed = 0
    failed = 0

    for seq_str, expected in test_cases:
        # Prepare input
        n = len(seq_str)
        if n > MAX_LEN:
            cocotb.log.warning(f"Skipping test '{seq_str}' (length {n} > max {MAX_LEN})")
            continue
        
        # Convert string to binary array: 1 for '(', 0 for ')'
        seq_vals = [1 if c == '(' else 0 for c in seq_str]
        
        cocotb.log.info(f"Testing sequence: '{seq_str}' (len={n}), expecting {'possible' if expected else 'impossible'}")
        
        # Check if seq_i is a bus or individual signals
        if has_signal(dut, 'seq_i'):
            # It's a bus or packed array, but for simplicity, we'll assume it's a bus of 16 bits or array
            # In Verilog spec, we asked for array of 16 1-bit elements.
            # Assuming 'seq_i' is a logic vector [15:0] or similar. 
            # However, generic testbench should handle individual elements.
            
            # Try to access seq_i as an array
            try:
                dut.seq_i.value = 0
                # Assume it's a flat vector for now if direct assignment fails for element access
                val = 0
                for i, v in enumerate(seq_vals):
                    val |= (v << i)
                dut.seq_i.value = clamp_to_width(val, 16)
                
                # If seq_i is actually an array of bits (e.g. dut.seq_i[0], dut.seq_i[1]...)
                # We handle this by trying to set elements, if 'seq_i' is a structure.
                # But since we can't know the exact structure, we rely on the vector assignment above 
                # or check for element access.
            except (AttributeError, TypeError):
                # Fallback: try individual elements seq_i_0, seq_i_1...
                # This matches the 'arr_i' style in some specs.
                pass
            
            # Detailed assignment for individual array elements if the bus approach is ambiguous
            # We check for specific naming conventions often used in generated HDL
            assigned = False
            for i in range(n):
                attr_name = f'seq_i_{i}'
                if has_signal(dut, attr_name):
                    getattr(dut, attr_name).value = seq_vals[i]
                    assigned = True
            if assigned:
                # Ensure unused bits are 0 if we found the array
                for i in range(n, MAX_LEN):
                    attr_name = f'seq_i_{i}'
                    if has_signal(dut, attr_name):
                        getattr(dut, attr_name).value = 0

        else:
            # Check for seq_0, seq_1... pattern
            assigned = False
            for i, v in enumerate(seq_vals):
                if has_signal(dut, f'seq_{i}'):
                    getattr(dut, f'seq_{i}').value = v
                    assigned = True
            if not assigned:
                raise TestFailure("Cannot find input signals for sequence (looked for seq_i, seq_0...)")

        # Set length
        if has_signal(dut, 'len_i'):
            dut.len_i.value = n
        elif has_signal(dut, 'len'):
            dut.len.value = n
        else:
            raise TestFailure("Length signal (len_i or len) missing")

        # Start process
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut, MAX_CYCLES)
        
        # Check result
        if not is_value_defined(dut.possible.value):
            raise TestFailure("Result 'possible' is undefined")
        
        result = int(dut.possible.value)
        exp_val = 1 if expected else 0
        
        if result == exp_val:
            cocotb.log.info(f"PASS: Got {result}, Expected {exp_val}")
            passed += 1
        else:
            cocotb.log.error(f"FAIL: Got {result}, Expected {exp_val}")
            failed += 1
        
        # Small delay between tests
        await Timer(100, units='ns')
        await reset_dut(dut)

    if failed > 0:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
