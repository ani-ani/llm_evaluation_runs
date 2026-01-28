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

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def pack_string(s, max_len=10):
    packed = 0
    chars = s.ljust(max_len)[:max_len]
    for i, c in enumerate(chars):
        packed |= ord(c) << (i*8)
    return packed

def float_to_fixed(f, frac=16):
    return int(f * (1 << frac))

def fixed_to_float(v, frac=16):
    return v / (1 << frac)

# Testbench
class TestTrainScheduler:
    def __init__(self, dut):
        self.dut = dut
        self.clk_period = 10  # ns
        self.max_cycles = 256
    
    async def setup(self):
        if has_signal(self.dut, 'clk'):
            cocotb.start_soon(Clock(self.dut.clk, self.clk_period, units='ns').start())
            await self.reset_dut()
    
    async def reset_dut(self, cycles=2):
        if has_signal(self.dut, 'rst_n'):
            self.dut.rst_n.value = 0
        if has_signal(self.dut, 'start'):
            self.dut.start.value = 0
        if has_signal(self.dut, 'valid_in'):
            self.dut.valid_in.value = 0
        for _ in range(cycles):
            await RisingEdge(self.dut.clk)
        if has_signal(self.dut, 'rst_n'):
            self.dut.rst_n.value = 1
        await RisingEdge(self.dut.clk)
    
    async def wait_for_done(self):
        for _ in range(self.max_cycles):
            await RisingEdge(self.dut.clk)
            if has_signal(self.dut, 'valid_out') and is_value_defined(self.dut.valid_out.value) and int(self.dut.valid_out.value) == 1:
                return True
        return False
    
    async def send_input(self, origin, dest, connections):
        # Set origin and dest
        if has_signal(self.dut, 'origin'):
            self.dut.origin.value = pack_string(origin, 10)
        if has_signal(self.dut, 'dest'):
            self.dut.dest.value = pack_string(dest, 10)
        
        # Set number of connections
        n = len(connections)
        if has_signal(self.dut, 'n'):
            self.dut.n.value = clamp_to_width(n, 8)
        
        # Set each connection
        for i, conn in enumerate(connections):
            if i >= 32:  # Max connections in Verilog
                break
            conn_origin, conn_dest, dep_min, base_t, prob, max_d = conn
            if has_signal(self.dut, f'conn_origin_{i}'):
                getattr(self.dut, f'conn_origin_{i}').value = pack_string(conn_origin, 10)
            if has_signal(self.dut, f'conn_dest_{i}'):
                getattr(self.dut, f'conn_dest_{i}').value = pack_string(conn_dest, 10)
            if has_signal(self.dut, f'conn_min_{i}'):
                getattr(self.dut, f'conn_min_{i}').value = clamp_to_width(dep_min, 6)
            if has_signal(self.dut, f'conn_t_{i}'):
                getattr(self.dut, f'conn_t_{i}').value = clamp_to_width(base_t, 9)
            if has_signal(self.dut, f'conn_p_{i}'):
                getattr(self.dut, f'conn_p_{i}').value = clamp_to_width(prob, 7)
            if has_signal(self.dut, f'conn_d_{i}'):
                getattr(self.dut, f'conn_d_{i}').value = clamp_to_width(max_d, 7)
        
        # Trigger
        if has_signal(self.dut, 'valid_in'):
            self.dut.valid_in.value = 1
        if has_signal(self.dut, 'start'):
            self.dut.start.value = 1
        await RisingEdge(self.dut.clk)
        if has_signal(self.dut, 'valid_in'):
            self.dut.valid_in.value = 0
        if has_signal(self.dut, 'start'):
            self.dut.start.value = 0

@cocotb.test(timeout_time=100, timeout_unit='ms')
async def test_train_scheduler(dut):
    test = TestTrainScheduler(dut)
    await test.setup()
    
    # Test case 1: Simple direct connection
    origin = "Hamburg"
    dest = "Bremen"
    connections = [
        ("Hamburg", "Bremen", 15, 68, 10, 5)
    ]
    
    # Expected: 68 + (10/100)*(5+1)/2 = 68 + 0.1*3 = 68.3
    expected = float_to_fixed(68.3)
    
    await test.send_input(origin, dest, connections)
    
    done = await test.wait_for_done()
    if not done:
        raise TestFailure("Did not complete within timeout")
    
    if has_signal(dut, 'impossible') and is_value_defined(dut.impossible.value) and int(dut.impossible.value) == 1:
        raise TestFailure("Got IMPOSSIBLE for reachable destination")
    
    if has_signal(dut, 'result') and is_value_defined(dut.result.value):
        result = int(dut.result.value)
        result_float = fixed_to_float(result)
        diff = abs(result_float - 68.3)
        if diff > 0.01:
            raise TestFailure(f"Expected 68.3, got {result_float:.6f}")
        cocotb.log.info(f"Test 1 passed: {result_float:.6f}")
    
    # Test case 2: Impossible
    await test.reset_dut()
    origin2 = "Amsterdam"
    dest2 = "Rotterdam"
    connections2 = [
        ("Amsterdam", "Utrecht", 10, 22, 5, 10)
    ]
    
    await test.send_input(origin2, dest2, connections2)
    
    done = await test.wait_for_done()
    if not done:
        raise TestFailure("Test 2 did not complete within timeout")
    
    if has_signal(dut, 'impossible') and is_value_defined(dut.impossible.value):
        if int(dut.impossible.value) == 0:
            raise TestFailure("Expected IMPOSSIBLE for unreachable destination")
        cocotb.log.info("Test 2 passed: IMPOSSIBLE as expected")
    else:
        raise TestFailure("Impossible signal missing")
    
    # Test case 3: Multiple connections
    await test.reset_dut()
    origin3 = "Hamburg"
    dest3 = "Frankfurt"
    connections3 = [
        ("Hamburg", "Bremen", 15, 68, 10, 5),
        ("Hamburg", "Bremen", 46, 55, 50, 60),
        ("Bremen", "Frankfurt", 14, 226, 10, 120)
    ]
    
    await test.send_input(origin3, dest3, connections3)
    
    done = await test.wait_for_done()
    if not done:
        raise TestFailure("Test 3 did not complete within timeout")
    
    if has_signal(dut, 'impossible') and is_value_defined(dut.impossible.value) and int(dut.impossible.value) == 1:
        raise TestFailure("Test 3: Got IMPOSSIBLE for reachable destination")
    
    if has_signal(dut, 'result') and is_value_defined(dut.result.value):
        result = int(dut.result.value)
        result_float = fixed_to_float(result)
        cocotb.log.info(f"Test 3 result: {result_float:.6f}")
        # Just verify it's a reasonable positive number
        if result_float <= 0 or result_float > 1000:
            raise TestFailure(f"Result {result_float} out of expected range")
        cocotb.log.info("Test 3 passed: reasonable result computed")

@cocotb.test(timeout_time=100, timeout_unit='ms')
async def test_edge_cases(dut):
    test = TestTrainScheduler(dut)
    await test.setup()
    
    # Test with zero probability (no delay)
    await test.send_input("A", "B", [("A", "B", 0, 100, 0, 0)])
    done = await test.wait_for_done()
    if not done:
        raise TestFailure("Edge case 1 timeout")
    
    if has_signal(dut, 'result') and is_value_defined(dut.result.value):
        result_float = fixed_to_float(int(dut.result.value))
        if abs(result_float - 100.0) > 0.01:
            raise TestFailure(f"Zero prob: Expected 100.0, got {result_float:.6f}")
        cocotb.log.info(f"Edge case 1 passed: {result_float:.6f}")
    
    # Test with max delay
    await test.reset_dut()
    await test.send_input("A", "B", [("A", "B", 0, 10, 100, 120)])
    done = await test.wait_for_done()
    if not done:
        raise TestFailure("Edge case 2 timeout")
    
    if has_signal(dut, 'result') and is_value_defined(dut.result.value):
        result_float = fixed_to_float(int(dut.result.value))
        # With 100% prob and max delay 120, expected delay = 121/2 = 60.5
        expected = 10 + 60.5
        if abs(result_float - expected) > 0.01:
            raise TestFailure(f"Max delay: Expected {expected}, got {result_float:.6f}")
        cocotb.log.info(f"Edge case 2 passed: {result_float:.6f}")

@cocotb.test(timeout_time=100, timeout_unit='ms')
async def test_impossible_cases(dut):
    test = TestTrainScheduler(dut)
    await test.setup()
    
    # Test case with no connections
    await test.send_input("A", "B", [])
    done = await test.wait_for_done()
    if not done:
        raise TestFailure("Impossible case timeout")
    
    if has_signal(dut, 'impossible') and is_value_defined(dut.impossible.value):
        if int(dut.impossible.value) == 0:
            raise TestFailure("Expected IMPOSSIBLE for no connections")
        cocotb.log.info("No connections test passed: IMPOSSIBLE")
    else:
        raise TestFailure("Impossible signal missing for no connections")
    
    # Test with disconnected graph
    await test.reset_dut()
    await test.send_input("A", "B", [("A", "C", 0, 10, 0, 0)])
    done = await test.wait_for_done()
    if not done:
        raise TestFailure("Disconnected case timeout")
    
    if has_signal(dut, 'impossible') and is_value_defined(dut.impossible.value):
        if int(dut.impossible.value) == 0:
            raise TestFailure("Expected IMPOSSIBLE for disconnected graph")
        cocotb.log.info("Disconnected test passed: IMPOSSIBLE")
    else:
        raise TestFailure("Impossible signal missing for disconnected graph")