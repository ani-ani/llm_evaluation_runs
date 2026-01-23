import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    """Safely convert cocotb value to int, returning default if X/Z."""
    try:
        return int(value)
    except ValueError:
        return default

def to_signed(val, bits):
    """Convert unsigned integer to signed (two's complement)."""
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    """Convert signed integer to unsigned for Verilog assignment."""
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# TESTBENCH
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_black_vienna_solver(dut):
    """Test the black_vienna_solver module."""
    
    # The module is combinational, so no clock needed.
    # We'll just set inputs and read output after a short delay.
    
    # Helper function to set an investigation
    def set_inv(inv_port, letter1, letter2, player, reply):
        """Set an investigation port."""
        # Convert letters to indices (A=0, B=1, C=2, D=3)
        letter1_idx = ord(letter1) - ord('A')
        letter2_idx = ord(letter2) - ord('A')
        # Encode into 7 bits: [6:5] letter1, [4:3] letter2, [2] player, [1:0] reply
        value = (letter1_idx << 5) | (letter2_idx << 3) | (player << 2) | (reply & 0x3)
        inv_port.value = value
    
    # Helper function to check count
    async def check_count(n, inv_list, expected):
        """Set investigations and check count."""
        # Set n
        dut.n.value = n
        
        # Set investigations (up to 5)
        inv_ports = [dut.inv0, dut.inv1, dut.inv2, dut.inv3, dut.inv4]
        for i in range(5):
            if i < n:
                inv = inv_list[i]
                set_inv(inv_ports[i], inv[0], inv[1], inv[2], inv[3])
            else:
                inv_ports[i].value = 0  # default
        
        # Wait for combinational logic to settle
        await Timer(100, units='ns')
        
        # Read count
        if not is_value_defined(dut.count.value):
            raise TestFailure("Count output is undefined")
        
        count = int(dut.count.value)
        if count != expected:
            raise TestFailure(f"Expected {expected}, got {count}")
        
        dut._log.info(f"Test passed: n={n}, inv={inv_list}, count={count}")
    
    # Test cases for M=4 (4 suspects, 3 in Black Vienna circle)
    # 1. No investigations -> all 8 assignments valid
    await check_count(0, [], 8)
    
    # 2. Three investigations: AB11, AC21, BC21 -> 0 valid
    await check_count(3, [('A','B',1,1), ('A','C',2,1), ('B','C',2,1)], 0)
    
    # 3. Three investigations: AB12, AC21, BC10 -> 0 valid
    await check_count(3, [('A','B',1,2), ('A','C',2,1), ('B','C',1,0)], 0)
    
    # 4. One investigation: AB11 -> 2 valid
    await check_count(1, [('A','B',1,1)], 2)
    
    dut._log.info("All tests passed!")