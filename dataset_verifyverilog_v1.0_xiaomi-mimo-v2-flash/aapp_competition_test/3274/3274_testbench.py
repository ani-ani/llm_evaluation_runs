import cocotb
from cocotb.triggers import Timer, RisingEdge, ClockCycles
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH, ARRAY_SIZE, CLK_NS, MAX_CYCLES = 16, 16, 10, 1000

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def encode_char(c):
    if c == '-': return 0x2D
    if c == '0': return 0x30
    if c == '+': return 0x2B
    return 0

def decode_result(result_val, n):
    chars = []
    for i in range(min(n, 8)):
        byte = (result_val >> (i*8)) & 0xFF
        if byte == 0x2D: chars.append('-')
        elif byte == 0x30: chars.append('0')
        elif byte == 0x2B: chars.append('+')
        else: chars.append('?')
    return ''.join(chars)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_torpedo_avoidance(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.ship_write.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    if has_signal(dut, 'done'):
        assert int(dut.done.value) == 0, "Done should be 0 after reset"
    
    test_cases = [
        {
            "n": 5,
            "m": 6,
            "ships": [
                (-3, -2, 3),
                (-2, -2, 4),
                (2, 3, 3),
                (-1, 1, 2),
                (0, 1, 4),
                (2, 5, 1)
            ],
            "expected": "--+0-"
        },
        {
            "n": 3,
            "m": 2,
            "ships": [
                (1, 2, 1),
                (-2, 0, 2)
            ],
            "expected": "0+-"
        },
        {
            "n": 3,
            "m": 2,
            "ships": [
                (1, 2, 1),
                (-2, 1, 2)
            ],
            "expected": "impossible"
        }
    ]
    
    for case_idx, case in enumerate(test_cases):
        cocotb.log.info(f"Running test case {case_idx + 1}")
        
        # Load ships
        for i, (x1, x2, y) in enumerate(case["ships"]):
            if i >= 16:
                cocotb.log.warning(f"Too many ships for hardware, limiting to 16")
                break
            
            dut.ship_idx.value = i
            dut.ship_x1.value = clamp_to_width(x1 + 8, 16)
            dut.ship_x2.value = clamp_to_width(x2 + 8, 16)
            dut.ship_y.value = clamp_to_width(y, 16)
            dut.ship_write.value = 1
            await RisingEdge(dut.clk)
            dut.ship_write.value = 0
        
        # Start computation
        dut.n.value = clamp_to_width(case["n"], 16)
        dut.m.value = clamp_to_width(case["m"], 8)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        cycles = 0
        done = False
        while cycles < 100 and not done:
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done = True
            cycles += 1
        
        if not done:
            raise TestFailure(f"Test case {case_idx + 1}: Timeout waiting for done")
        
        # Check result
        if not is_value_defined(dut.possible.value):
            raise TestFailure(f"Test case {case_idx + 1}: possible signal undefined")
        
        possible = int(dut.possible.value)
        
        if case["expected"] == "impossible":
            if possible != 0:
                raise TestFailure(f"Test case {case_idx + 1}: Expected impossible, got possible")
        else:
            if possible != 1:
                raise TestFailure(f"Test case {case_idx + 1}: Expected possible, got impossible")
            
            if not is_value_defined(dut.result.value):
                raise TestFailure(f"Test case {case_idx + 1}: result undefined")
            
            result_val = int(dut.result.value)
            output_str = decode_result(result_val, case["n"])
            
            if output_str != case["expected"]:
                raise TestFailure(f"Test case {case_idx + 1}: Expected '{case["expected"]}', got '{output_str}'")
        
        cocotb.log.info(f"Test case {case_idx + 1}: PASSED")
        
        # Reset for next test
        dut.rst_n.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)