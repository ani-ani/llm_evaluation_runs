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

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_lnns_reverse(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: (sequence_bits, seq_len, expected_result, description)
    # Bit 0 = 1, Bit 1 = 2
    # Example 1: [1,2,1,2] -> reverse [2,3] -> [1,1,2,2] -> LNDS = 4
    # Bits: 1(0), 0(1), 2(2), 1(3) -> Wait, order is LSB first.
    # Sequence: [1,2,1,2] -> Bits: 0, 1, 0, 1 -> Packed: 0b1010 = 10
    test_cases = [
        (0b1010, 4, 4, "Example 1: [1,2,1,2]"),
        (0b1100110001, 10, 9, "Example 2: [1,1,2,2,2,1,1,2,2,1]"),
        (0b0, 1, 1, "Single 1"),
        (0b1, 1, 1, "Single 2"),
        (0b01, 2, 2, "[1,2]"),
        (0b10, 2, 2, "[2,1]"),
    ]
    
    passed = 0
    failed = 0
    
    for seq_bits, seq_len, exp, desc in test_cases:
        cocotb.log.info(f"Test: {desc}")
        try:
            if is_seq:
                # Drive inputs
                dut.seq.value = seq_bits
                dut.len.value = seq_len
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut)
                
                # Read result
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result undefined")
                    
                result = int(dut.result.value)
            else:
                # Combinational: just set inputs and wait
                if has_signal(dut, 'seq'):
                    dut.seq.value = seq_bits
                if has_signal(dut, 'len'):
                    dut.len.value = seq_len
                await Timer(100, units='ns')
                result = int(dut.result.value)
            
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {desc} - {e}")
            failed += 1
    
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed")