import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 4  # 4-bit signed coordinates
ARRAY_SIZE = 8
CLK_NS = 10
MAX_CYCLES = 1000

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

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Pack triangle coordinates into 48-bit (using 4-bit per coordinate)
def pack_tri(x1, y1, x2, y2, x3, y3):
    # Convert to signed 4-bit representation
    # Input range: -8..7 for 4-bit signed
    def to_4bit_signed(v):
        if v < -8: v = -8
        if v > 7: v = 7
        return v & 0xF  # Already clamped
    
    x1s = to_4bit_signed(x1)
    y1s = to_4bit_signed(y1)
    x2s = to_4bit_signed(x2)
    y2s = to_4bit_signed(y2)
    x3s = to_4bit_signed(x3)
    y3s = to_4bit_signed(y3)
    
    return (x1s) | (y1s << 4) | (x2s << 8) | (y2s << 12) | (x3s << 16) | (y3s << 20)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_module(dut):
    # Clock setup
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases adapted to 16x16 grid
    # Case 1: Identical single triangle
    # Triangle: (0,0), (4,0), (0,4) -> right triangle, area ~8 pixels
    tri1 = pack_tri(0, 0, 4, 0, 0, 4)
    
    # Case 2: Different partitions (should be same area)
    # SetA: Two triangles splitting the same right triangle
    # Triangle A1: (0,0), (2,0), (0,2)
    # Triangle A2: (2,0), (4,0), (0,4) -- careful with non-overlapping
    # Better: (2,0), (4,0), (0,2) + (0,2), (2,0), (0,4) -> area 2+6=8
    triA1 = pack_tri(0, 0, 2, 0, 0, 2)
    triA2 = pack_tri(2, 0, 4, 0, 0, 2)
    triA3 = pack_tri(0, 2, 2, 0, 0, 4)
    
    # SetB: Different shape, same area? Let's use a 3x3 square = 9 pixels
    # Triangle B1: (0,0), (3,0), (0,3)
    # Triangle B2: (3,0), (6,0), (0,6) -- too big
    # Keep it simple: 4x4 square = 16 pixels (too big for threshold)
    # Use 2x2 square = 4 pixels
    triB1 = pack_tri(0, 0, 2, 0, 0, 2)  # Area 2
    triB2 = pack_tri(2, 0, 2, 2, 0, 2)  # Area 2
    
    test_cases = [
        # (setA_tris, setA_count, setB_tris, setB_count, expected_same)
        ([tri1], 1, [tri1], 1, True),  # Identical
        ([tri1], 1, [tri1, tri1], 2, False),  # Different count
        ([triA1, triA2], 2, [triB1, triB2], 2, True),  # Both area 4
        ([pack_tri(0,0,5,0,0,5)], 1, [pack_tri(0,0,4,0,0,4)], 1, False),  # Different areas
        ([], 0, [], 0, True),  # Both empty
        ([tri1], 1, [], 0, False),  # One empty
    ]
    
    passed = 0
    failed = 0
    
    for i, (setA, countA, setB, countB, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: A={countA} tris, B={countB} tris")
        try:
            # Load setA triangles
            for idx in range(ARRAY_SIZE):
                if idx < len(setA):
                    getattr(dut, f'setA_tri_{idx}').value = setA[idx]
                else:
                    getattr(dut, f'setA_tri_{idx}').value = 0
            
            # Load setB triangles
            for idx in range(ARRAY_SIZE):
                if idx < len(setB):
                    getattr(dut, f'setB_tri_{idx}').value = setB[idx]
                else:
                    getattr(dut, f'setB_tri_{idx}').value = 0
            
            # Set counts
            if has_signal(dut, 'setA_count'):
                dut.setA_count.value = countA
            if has_signal(dut, 'setB_count'):
                dut.setB_count.value = countB
            
            # Start
            await RisingEdge(dut.clk)
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Check result
            if not is_value_defined(dut.same.value):
                raise TestFailure("Result 'same' undefined")
            
            result = int(dut.same.value) == 1
            if result != expected:
                raise TestFailure(f"Expected same={expected}, got {result}")
            
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
        
        await RisingEdge(dut.clk)  # Inter-test delay
    
    if failed:
        raise TestFailure(f"{failed} tests failed")
