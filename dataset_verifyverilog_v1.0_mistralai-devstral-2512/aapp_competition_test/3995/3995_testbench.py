import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# --- Helpers ---
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

# --- Python Reference Logic ---
def py_generate_string(n, k):
    if n == k:
        return '1' * n
    l = (n - k) // 2 + 1
    pattern = '0' * (l - 1) + '1'
    result = (pattern * ((n // l) + 1))[:n]
    return result

# --- Testbench ---
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_minimal_unique_substring(dut):
    # Setup Clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases (scaled to 8-bit range)
    test_cases = [
        (4, 4),   # All 1s
        (5, 3),   # Pattern
        (7, 3),   # Pattern
        (1, 1),   # Single 1
        (2, 2),   # 11
        (3, 1),   # Pattern
        (10, 8),  # Edge case
        (20, 4)   # Larger case
    ]
    
    for n_val, k_val in test_cases:
        # Skip if inputs are wider than HDL ports (check definition if needed, assuming 8-bit inputs)
        if n_val > 255 or k_val > 255:
            continue
            
        cocotb.log.info(f"Testing n={n_val}, k={k_val}")
        
        # Drive inputs
        dut.n_in.value = n_val
        dut.k_in.value = k_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read outputs
        result_hex = dut.result.value
        length_out = int(dut.length_out.value)
        
        # Convert binary string result from integer
        result_bin_str = format(int(result_hex), 'b').zfill(128)[-128:]
        
        # Trim to valid length (assuming MSB is the start of the string, or LSB)
        # Let's assume standard HDL convention: result[length-1:0] contains the data.
        # However, since we construct 'pattern', the first char is the first bit.
        # In Python, we generate a string like "01010". We need to map this to bits.
        # If we treat LSB as index 0, then "01010" -> 0b01010 = 10.
        # Let's check the generated value.
        
        # Extract valid bits
        valid_bits = result_bin_str[-length_out:]
        if length_out == 0:
            valid_bits = ""
            
        # Reverse to match LSB 0 indexing if Python string is MSB first
        # Python string "01010" (index 0='0') -> Bits: Bit 4=0, Bit 3=1, ...
        # Typically HDL output is packed. Let's assume result[0] corresponds to string index 0.
        # So we map directly: Python string index i -> Bit i.
        
        # Reconstruct string from bits
        # valid_bits are read from MSB of register down? 
        # If dut.result is 128 bits, int(dut.result) gives the value.
        # bit i corresponds to 2^i.  
        # So bit 0 is LSB.  
        # Python string s[0] is first character.
        # We need to compare s with the bits.
        
        reconstructed = []
        for i in range(length_out):
            # Check bit i of the result integer
            bit = (int(result_hex) >> i) & 1
            reconstructed.append(str(bit))
        
        result_string = "".join(reconstructed)
        
        # Generate expected string
        expected = py_generate_string(n_val, k_val)
        
        if result_string != expected:
            raise TestFailure(f"Mismatch for n={n_val}, k={k_val}: Expected '{expected}', got '{result_string}' (len={length_out})")
        
        cocotb.log.info(f"Success: '{result_string}'")
        
        # Wait a cycle before next test
        await RisingEdge(dut.clk)
