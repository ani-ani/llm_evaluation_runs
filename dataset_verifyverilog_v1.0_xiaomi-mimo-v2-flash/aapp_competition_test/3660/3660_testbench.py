import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants for scaled problem
MAX_MSG_LEN = 8
MAX_STICKERS = 16
STICKER_WIDTH = 6
DATA_WIDTH = 8
CLK_NS = 10
MAX_CYCLES = 500

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except (ValueError, TypeError):
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except (ValueError, TypeError):
        return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def to_q16_16(f):
    """Convert float to Q16.16 fixed point"""
    return int(f * (1 << 16))

def from_q16_16(v):
    """Convert Q16.16 fixed point to float"""
    return v / (1 << 16)

def encode_sticker(chars, start, end, price):
    """Pack sticker into 64-bit: {start:3b, end:3b, price:16b, chars:32b}"""
    char_bits = 0
    for i, c in enumerate(chars):
        if i < 4:  # 4 chars max for 32-bit field (8 bits each)
            char_bits |= (ord(c) << (i * 8))
    start_bit = start & 0x7
    end_bit = end & 0x7
    price_bits = clamp_to_width(price, 16)
    return (char_bits | (price_bits << 32) | (end_bit << 48) | (start_bit << 51)) & 0xFFFFFFFFFFFFFFFF

def encode_msg(msg):
    """Encode message as list of 8-bit chars, padded to 8"""
    result = [ord(c) for c in msg[:MAX_MSG_LEN]]
    while len(result) < MAX_MSG_LEN:
        result.append(0)  # Null terminator
    return result

async def reset_dut(dut, cycles=2):
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    if has_signal(dut, 'msg_valid'):
        dut.msg_valid.value = 0
    if has_signal(dut, 'sticker_valid'):
        dut.sticker_valid.value = 0
    
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def load_message(dut, msg_str):
    """Load message character by character"""
    encoded = encode_msg(msg_str)
    for i, char in enumerate(encoded):
        if has_signal(dut, 'msg_valid'):
            dut.msg_valid.value = 1
        if has_signal(dut, 'msg_data'):
            dut.msg_data.value = clamp_to_width(char, 8)
        await RisingEdge(dut.clk)
    if has_signal(dut, 'msg_valid'):
        dut.msg_valid.value = 0

async def load_sticker(dut, chars, start, end, price):
    """Load one sticker"""
    sticker_bits = encode_sticker(chars, start, end, price)
    if has_signal(dut, 'sticker_valid'):
        dut.sticker_valid.value = 1
    if has_signal(dut, 'sticker_data'):
        dut.sticker_data.value = sticker_bits
    await RisingEdge(dut.clk)
    if has_signal(dut, 'sticker_valid'):
        dut.sticker_valid.value = 0

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_sticker_message(dut):
    """Test the sticker message processor"""
    
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational module
        await Timer(10, units='ns')
    
    # Test cases: (message, stickers_list, expected_cost, desc, should_be_impossible)
    test_cases = [
        (
            "BUYRICK",  # Shortened from BUYSTICKERS
            [("BUYER", 0, 4, 10.0), ("STICKY", 2, 7, 10.0), ("TICKERS", 3, 7, 1.0), ("ERS", 5, 7, 8.0)],
            28.0,
            "Example case",
            False
        ),
        (
            "ABBBAA",  # Extended ABBA for 8 chars
            [("AAAAA", 0, 4, 10.0), ("BB", 2, 3, 3.0)],
            0.0,
            "Impossible case (modified)",
            True
        ),
        (
            "AAAAAAA",  # All same letters
            [("AAAAA", 0, 4, 5.0), ("AAA", 0, 2, 2.0), ("AA", 3, 4, 1.0), ("A", 0, 0, 0.5)],
            7.5,
            "Simple overlapping",
            False
        )
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, (msg, stickers, exp_cost, desc, should_be_impossible) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {test_idx + 1}: {desc}")
        cocotb.log.info(f"  Message: {msg}")
        cocotb.log.info(f"  Stickers: {len(stickers)} types")
        
        try:
            # Reset for each test
            if has_signal(dut, 'rst_n'):
                await reset_dut(dut, cycles=2)
            else:
                await Timer(100, units='ns')
            
            # Load message
            if has_signal(dut, 'msg_data') or has_signal(dut, 'msg_valid'):
                await load_message(dut, msg)
            
            # Load stickers
            if has_signal(dut, 'sticker_data'):
                for chars, start, end, price in stickers:
                    # Scale for 8-char message
                    scale_factor = MAX_MSG_LEN / len(msg)
                    start_scaled = int(start * scale_factor)
                    end_scaled = int(end * scale_factor)
                    if end_scaled >= MAX_MSG_LEN:
                        end_scaled = MAX_MSG_LEN - 1
                    if start_scaled < 0:
                        start_scaled = 0
                    if start_scaled >= MAX_MSG_LEN:
                        start_scaled = MAX_MSG_LEN - 1
                    if end_scaled < start_scaled:
                        end_scaled = start_scaled
                    
                    # Truncate chars to fit 6-char limit for scaled problem
                    chars_truncated = chars[:STICKER_WIDTH]
                    
                    await load_sticker(dut, chars_truncated, start_scaled, end_scaled, price)
            
            # Start processing
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
            else:
                # Combinational: wait for calculation
                await Timer(100, units='ns')
            
            # Wait for done
            if has_signal(dut, 'done'):
                await wait_for_done(dut, max_cycles=MAX_CYCLES)
            
            # Read results
            result_cost = 0
            impossible = 0
            
            if has_signal(dut, 'impossible') and is_value_defined(dut.impossible.value):
                impossible = int(dut.impossible.value)
            
            if has_signal(dut, 'result_cost') and is_value_defined(dut.result_cost.value):
                result_cost = int(dut.result_cost.value)
            
            if has_signal(dut, 'result_valid') and is_value_defined(dut.result_valid.value):
                if int(dut.result_valid.value) == 0:
                    raise TestFailure("Result valid flag is 0")
            
            # Check results
            if should_be_impossible:
                if impossible != 1:
                    raise TestFailure(f"Expected IMPOSSIBLE, but got cost = {result_cost}")
                cocotb.log.info(f"  ✓ Correctly returned IMPOSSIBLE")
            else:
                if impossible == 1:
                    raise TestFailure("Expected cost, but got IMPOSSIBLE")
                
                # Compare costs with tolerance for fixed-point
                exp_cost_q16 = to_q16_16(exp_cost)
                result_q16 = result_cost
                
                # Allow small rounding errors
                tolerance = 100  # ~0.0015 in Q16.16
                if abs(result_q16 - exp_cost_q16) > tolerance:
                    raise TestFailure(f"Expected {exp_cost} ({exp_cost_q16}), got {from_q16_16(result_q16)} ({result_q16})")
                
                cocotb.log.info(f"  ✓ Correct cost: {from_q16_16(result_q16)}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        await Timer(100, units='ns')  # Small gap between tests
    
    if failed > 0:
        raise TestFailure(f"{failed} of {len(test_cases)} tests failed")
    
    cocotb.log.info(f"\n✓ All {passed} tests passed")
