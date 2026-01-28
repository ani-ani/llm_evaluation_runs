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

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def pack_commands(cmds):
    """Pack up to 16 commands into 32-bit value"""
    result = 0
    for i, cmd in enumerate(cmds[:16]):
        cmd_val = {'U': 0, 'D': 1, 'L': 2, 'R': 3}[cmd]
        result |= cmd_val << (2 * i)
    return result

def calculate_path(cmds):
    """Calculate cumulative positions for Python reference"""
    positions = [(0, 0)]
    x, y = 0, 0
    for cmd in cmds:
        if cmd == 'U': y += 1
        elif cmd == 'D': y -= 1
        elif cmd == 'L': x -= 1
        elif cmd == 'R': x += 1
        positions.append((x, y))
    return positions

def check_reach_python(a, b, cmds):
    """Python reference implementation"""
    positions = calculate_path(cmds)
    net_x = positions[-1][0]
    net_y = positions[-1][1]
    
    for i, (xi, yi) in enumerate(positions):
        # Case 1: Net displacement is zero (loop)
        if net_x == 0 and net_y == 0:
            if a == xi and b == yi:
                return True
            continue
        
        # Case 2: Only net_x is zero
        if net_x == 0:
            if a == xi and (b - yi) != 0:
                if net_y != 0 and (b - yi) % net_y == 0:
                    times = (b - yi) // net_y
                    if times >= 0:
                        return True
            elif a == xi and (b - yi) == 0:
                return True
        
        # Case 3: Only net_y is zero
        if net_y == 0:
            if b == yi and (a - xi) != 0:
                if net_x != 0 and (a - xi) % net_x == 0:
                    times = (a - xi) // net_x
                    if times >= 0:
                        return True
            elif b == yi and (a - xi) == 0:
                return True
        
        # Case 4: Both non-zero
        if net_x != 0 and net_y != 0:
            dx = a - xi
            dy = b - yi
            if dx % net_x == 0 and dy % net_y == 0:
                times_x = dx // net_x
                times_y = dy // net_y
                if times_x == times_y and times_x >= 0:
                    return True
    
    return False

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

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_robot_reach(dut):
    # Setup clock
    CLK_NS = 10
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (a, b, cmd_sequence, expected_result)
    test_cases = [
        (2, 2, "RU", True),
        (1, 2, "RU", False),
        (-1, 1000000000, "LRRLU", True),
        (0, 0, "D", True),
        (0, 0, "UURRDL", True),
        (3, 3, "UURR", True),
        (-2, -2, "UR", False),
        (5, 5, "UDLR", False),
        (0, -1, "U", False),
        (-1, 0, "R", True),
        (1, 1, "LD", False),
        (-2, -2, "UURR", False),
        (0, 1, "UDLR", False),
        (0, -3, "RDDL", True),
    ]
    
    passed = 0
    failed = 0
    
    for i, (a, b, cmd_str, expected) in enumerate(test_cases):
        # Scale coordinates to 14-bit signed
        if not (-16384 <= a <= 16383) or not (-16384 <= b <= 16383):
            cocotb.log.info(f"Test {i+1}: Skipping due to coordinate out of 14-bit range")
            continue
        
        cmd_str = cmd_str[:16]  # Limit to 16 commands
        len_val = len(cmd_str)
        packed_cmds = pack_commands(cmd_str)
        
        # Reference check
        ref_result = check_reach_python(a, b, cmd_str)
        if ref_result != expected:
            cocotb.log.warning(f"Test {i+1}: Python reference mismatch! Got {ref_result}, expected {expected}")
        
        cocotb.log.info(f"Test {i+1}: a={a}, b={b}, cmds='{cmd_str}' (len={len_val})")
        
        try:
            # Set inputs
            dut.a.value = from_signed(a, 14) if a < 0 else a
            dut.b.value = from_signed(b, 14) if b < 0 else b
            dut.seq_len.value = len_val
            dut.cmd.value = packed_cmds
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result_val = int(dut.result.value)
            expected_val = 1 if expected else 0
            
            if result_val != expected_val:
                raise TestFailure(f"Expected {expected_val}, got {result_val}")
            
            passed += 1
            cocotb.log.info(f"  PASS: Result={result_val} (correct)")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    cocotb.log.info(f"\nSummary: {passed}/{len(test_cases)} passed")
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")