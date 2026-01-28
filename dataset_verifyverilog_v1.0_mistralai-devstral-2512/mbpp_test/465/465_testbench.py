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

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

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

# Testbench
@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_dict_drop_empty(dut):
    # Setup Clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)

    # Test Cases
    # Case 1: {'c1': 'Red', 'c2': 'Green', 'c3':None} -> 2 entries
    # Keys: 'c1', 'c2', 'c3' (arbitrary mapping to 4-bit keys: 1, 2, 3)
    # Values: 'Red'->0xAA, 'Green'->0xBB, None->0xFF
    test_cases = [
        {
            "keys": [1, 2, 3],
            "vals": [0xAA, 0xBB, 0xFF],
            "valid_mask": 0b00000111,  # 3 valid inputs
            "exp_keys": [1, 2, 0],
            "exp_vals": [0xAA, 0xBB, 0],
            "exp_count": 2,
            "desc": "Drop None at end"
        },
        {
            "keys": [1, 2, 3],
            "vals": [0xAA, 0xFF, 0xFF],
            "valid_mask": 0b00000111,
            "exp_keys": [1, 0, 0],
            "exp_vals": [0xAA, 0, 0],
            "exp_count": 1,
            "desc": "Drop None middle/end"
        },
        {
            "keys": [1, 2, 3],
            "vals": [0xFF, 0xBB, 0xFF],
            "valid_mask": 0b00000111,
            "exp_keys": [2, 0, 0],
            "exp_vals": [0xBB, 0, 0],
            "exp_count": 1,
            "desc": "Drop None start/end"
        }
    ]

    passed = 0
    failed = 0

    for tc in test_cases:
        cocotb.log.info(f"Test: {tc['desc']}")
        try:
            # Input setup
            for i in range(8):
                # Set key and val for all 8 slots (pad with 0 if not in test)
                if i < len(tc['keys']):
                    dut.key_in[i].value = clamp_to_width(tc['keys'][i], 4)
                    dut.val_in[i].value = clamp_to_width(tc['vals'][i], 8)
                else:
                    dut.key_in[i].value = 0
                    dut.val_in[i].value = 0
            dut.valid_in.value = tc['valid_mask']
            
            # Start
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Verify Results
            result_count = int(dut.result_count.value)
            if result_count != tc['exp_count']:
                raise TestFailure(f"Result count mismatch. Expected {tc['exp_count']}, got {result_count}")
            
            for i in range(8):
                k_out = int(dut.key_out[i].value)
                v_out = int(dut.val_out[i].value)
                
                exp_k = tc['exp_keys'][i] if i < len(tc['exp_keys']) else 0
                exp_v = tc['exp_vals'][i] if i < len(tc['exp_vals']) else 0
                
                if k_out != exp_k:
                    raise TestFailure(f"Key mismatch at index {i}. Expected {exp_k}, got {k_out}")
                if v_out != exp_v:
                    raise TestFailure(f"Value mismatch at index {i}. Expected {exp_v}, got {v_out}")
                    
            passed += 1
            cocotb.log.info(f"PASS: {tc['desc']}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {tc['desc']} - {e}")
            failed += 1
            # Reset for next test
            await reset_dut(dut)

    if failed:
        raise TestFailure(f"{failed} tests failed")
