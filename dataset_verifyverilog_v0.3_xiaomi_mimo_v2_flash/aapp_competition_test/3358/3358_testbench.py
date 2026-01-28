import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# MANDATORY HELPER FUNCTIONS
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
# INSTRUCTION ENCODING
# ============================================================================

OPCODES = {
    'ST': 0,
    'ZE': 1,
    'PH': 2,
    'PL': 3,
    'AD': 4,
    'DI': 5
}

REGS = {
    'A': 0,
    'X': 1,
    'Y': 2
}

def encode_instruction(opcode_str, reg_str=None):
    """Encode instruction into 8-bit value."""
    opcode = OPCODES[opcode_str]
    reg = REGS.get(reg_str, 0) if reg_str else 0
    return (opcode << 5) | (reg << 3)

# ============================================================================
# TEST CASES
# ============================================================================

test_cases = [
    (0, [
        encode_instruction('ZE', 'Y'),
        encode_instruction('DI', 'Y')
    ]),
    (1, [
        encode_instruction('ST', 'Y'),
        encode_instruction('DI', 'Y')
    ]),
    (2, [
        encode_instruction('ST', 'A'),
        encode_instruction('ST', 'X'),
        encode_instruction('PH', 'A'),
        encode_instruction('PH', 'X'),
        encode_instruction('AD'),
        encode_instruction('PL', 'Y'),
        encode_instruction('DI', 'Y')
    ]),
    (5, [
        encode_instruction('ST', 'X'),
        encode_instruction('PH', 'X'),
        encode_instruction('PH', 'X'),
        encode_instruction('PH', 'X'),
        encode_instruction('AD'),
        encode_instruction('PL', 'Y'),
        encode_instruction('PH', 'Y'),
        encode_instruction('PH', 'Y'),
        encode_instruction('AD'),
        encode_instruction('AD'),
        encode_instruction('PL', 'A'),
        encode_instruction('DI', 'A')
    ])
]

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit='ms')
async def test_program_generator(dut):
    """Test the program generator for several N values."""
    
    # Detect interface
    has_clk = has_signal(dut, 'clk')
    has_rst = has_signal(dut, 'rst_n')
    has_start = has_signal(dut, 'start')
    has_valid = has_signal(dut, 'valid')
    has_done = has_signal(dut, 'done')
    has_N = has_signal(dut, 'N')
    has_instr = has_signal(dut, 'instruction')
    
    if not all([has_clk, has_rst, has_start, has_N, has_instr, has_valid, has_done]):
        cocotb.log.error("Missing required signals")
        raise TestFailure("DUT must have clk, rst_n, start, N, instruction, valid, done")
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.N.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    for n, expected_instructions in test_cases:
        cocotb.log.info(f"Testing N = {n}")
        
        # Set N and start
        dut.N.value = n
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Collect generated instructions
        generated = []
        timeout = 50  # max cycles to wait
        
        for cycle in range(timeout):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.valid.value) and int(dut.valid.value) == 1:
                instr = int(dut.instruction.value)
                generated.append(instr)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
        else:
            raise TestFailure(f"Timeout waiting for done for N={n}")
        
        # Verify
        if len(generated) != len(expected_instructions):
            raise TestFailure(f"N={n}: expected {len(expected_instructions)} instructions, got {len(generated)}")
        
        for i, (exp, gen) in enumerate(zip(expected_instructions, generated)):
            if gen != exp:
                raise TestFailure(f"N={n} instr {i}: expected {exp:08b}, got {gen:08b}")
        
        cocotb.log.info(f"  PASS: {len(generated)} instructions generated correctly")
    
    cocotb.log.info("All tests passed")