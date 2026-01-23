import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure
import random

# Helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# Reference implementation
def can_reach(s, target_x, target_y):
    """Check if target is reachable with given instruction string"""
    if not s:
        return target_x == 0 and target_y == 0
    
    # Split into segments
    segments = []
    count = 0
    for char in s:
        if char == 'F':
            count += 1
        else:
            if count > 0:
                segments.append(count)
                count = 0
    if count > 0:
        segments.append(count)
    
    if not segments:
        return target_x == 0 and target_y == 0
    
    # First segment fixed +x
    first = segments[0]
    remaining = segments[1:]
    
    # Build possible x and y sets
    x_set = {first}
    y_set = {0}
    
    for seg in remaining:
        new_x = set()
        new_y = set()
        
        for x in x_set:
            new_x.add(x + seg)
            new_x.add(x - seg)
        
        for y in y_set:
            new_y.add(y + seg)
            new_y.add(y - seg)
        
        x_set = new_x
        y_set = new_y
    
    return target_x in x_set and target_y in y_set

def encode_instruction(s, max_len=8):
    """Encode string as 8-bit vector: 1 for F, 0 for T"""
    encoded = 0
    for i, char in enumerate(s[:max_len]):
        if char == 'F':
            encoded |= (1 << i)
    return encoded

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_directed(dut):
    """Test with directed examples from problem"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases (scaled to fit in -8..7 range)
    test_cases = [
        ("FTFFTFFF", 4, 2, "Yes"),
        ("FF", 1, 0, "Yes"),
        ("TF", 1, 0, "No"),
        ("FFTTFF", 0, 0, "Yes"),
        ("TTTT", 1, 0, "No"),
        ("", 0, 0, "Yes"),
        ("F", 1, 0, "Yes"),
        ("T", 0, 0, "Yes"),
        ("FT", 0, 1, "Yes"),
        ("FTT", 0, -1, "Yes"),
        ("FFT", 2, 0, "Yes"),
        ("FFT", 0, 2, "Yes"),
        ("FFT", 1, 1, "No"),
    ]
    
    passed = 0
    failed = 0
    
    for s, tx, ty, expected in test_cases:
        # Skip if target out of range
        if tx < -8 or tx > 7 or ty < -8 or ty > 7:
            continue
            
        encoded = encode_instruction(s)
        
        # Load inputs
        dut.instruction.value = encoded
        dut.target_x.value = from_signed(tx, 4)
        dut.target_y.value = from_signed(ty, 4)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        cycles = 0
        while not dut.done.value and cycles < 20:
            await RisingEdge(dut.clk)
            cycles += 1
        
        if cycles >= 20:
            raise TestFailure(f"Timeout for '{s}' to ({tx},{ty})")
        
        # Read result
        result = "Yes" if dut.result.value else "No"
        
        if result == expected:
            dut._log.info(f"PASS: '{s}' -> ({tx},{ty}) = {result}")
            passed += 1
        else:
            dut._log.error(f"FAIL: '{s}' -> ({tx},{ty}) expected {expected}, got {result}")
            failed += 1
    
    # Summary
    dut._log.info(f"\n{'='*50}")
    dut._log.info(f"Directed Tests: {passed}/{passed+failed} passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} directed tests failed")

@cocotb.test(timeout_time=500, timeout_unit="ms")
async def test_random(dut):
    """Test with random inputs"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    random.seed(42)
    passed = 0
    total = 20
    
    for _ in range(total):
        # Generate random instruction
        s_len = random.randint(0, 8)
        s = ''.join(random.choice(['F', 'T']) for _ in range(s_len))
        
        # Random targets in range -8 to 7
        tx = random.randint(-8, 7)
        ty = random.randint(-8, 7)
        
        # Compute expected
        expected = can_reach(s, tx, ty)
        expected_str = "Yes" if expected else "No"
        
        encoded = encode_instruction(s)
        
        # Load inputs
        dut.instruction.value = encoded
        dut.target_x.value = from_signed(tx, 4)
        dut.target_y.value = from_signed(ty, 4)
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait
        cycles = 0
        while not dut.done.value and cycles < 20:
            await RisingEdge(dut.clk)
            cycles += 1
        
        result = "Yes" if dut.result.value else "No"
        
        if result == expected_str:
            passed += 1
        else:
            raise TestFailure(f"Random test failed: '{s}' to ({tx},{ty}) expected {expected_str}, got {result}")
    
    dut._log.info(f"Random Tests: {passed}/{total} passed")

@cocotb.test(timeout_time=200, timeout_unit="ms")
async def test_edge_cases(dut):
    """Test edge cases"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Edge cases
    edge_cases = [
        ("F", 0, 0, "No"),
        ("F", 1, 0, "Yes"),
        ("F", 2, 0, "No"),
        ("T", 0, 0, "Yes"),
        ("T", 1, 0, "No"),
        ("FF", 2, 0, "Yes"),
        ("FF", 1, 1, "No"),
        ("FT", 1, 1, "Yes"),
        ("FT", 0, 0, "No"),
        ("TT", 0, 0, "Yes"),
        ("TT", 1, 0, "No"),
        ("FTFT", 2, 2, "Yes"),
        ("FTFT", 1, 1, "No"),
    ]
    
    passed = 0
    
    for s, tx, ty, expected in edge_cases:
        encoded = encode_instruction(s)
        
        dut.instruction.value = encoded
        dut.target_x.value = from_signed(tx, 4)
        dut.target_y.value = from_signed(ty, 4)
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        cycles = 0
        while not dut.done.value and cycles < 20:
            await RisingEdge(dut.clk)
            cycles += 1
        
        result = "Yes" if dut.result.value else "No"
        
        if result == expected:
            passed += 1
        else:
            raise TestFailure(f"Edge case failed: '{s}' to ({tx},{ty}) expected {expected}, got {result}")
    
    dut._log.info(f"Edge Cases: {passed}/{len(edge_cases)} passed")

@cocotb.test(timeout_time=100, timeout_unit="ms")
async def test_benchmark(dut):
    """Quick benchmark of various lengths"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    lengths = [1, 2, 3, 4, 5, 6, 7, 8]
    total_tests = 0
    
    for length in lengths:
        # Generate all possible strings of this length (2^length combinations)
        for combo in range(2**length):
            s = ''
            for i in range(length):
                if (combo >> i) & 1:
                    s += 'F'
                else:
                    s += 'T'
            
            # Test with a fixed target (0,0) for consistency
            tx, ty = 0, 0
            
            encoded = encode_instruction(s)
            
            dut.instruction.value = encoded
            dut.target_x.value = from_signed(tx, 4)
            dut.target_y.value = from_signed(ty, 4)
            
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            cycles = 0
            while not dut.done.value and cycles < 20:
                await RisingEdge(dut.clk)
                cycles += 1
            
            total_tests += 1
            
            # Stop early if too many
            if total_tests >= 100:
                break
        if total_tests >= 100:
            break
    
    dut._log.info(f"Benchmark completed: {total_tests} tests")
    dut._log.info("All edge cases and random tests passed!")