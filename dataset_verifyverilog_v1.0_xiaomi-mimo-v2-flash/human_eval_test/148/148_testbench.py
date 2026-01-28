import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# --- Helpers ---
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def pack_bytes(vals):
    result = 0
    for i, v in enumerate(vals):
        result |= (v & 0xFF) << (i * 8)
    return result

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=20):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=10, timeout_unit='ms')
async def test_planets(dut):
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational test
        await Timer(1, units='ns')
        dut.rst_n.value = 1

    # Planet mapping: 0=Mercury, 1=Venus, 2=Earth, 3=Mars, 4=Jupiter, 5=Saturn, 6=Uranus, 7=Neptune
    planet_map = {
        "Mercury": 0, "Venus": 1, "Earth": 2, "Mars": 3,
        "Jupiter": 4, "Saturn": 5, "Uranus": 6, "Neptune": 7
    }

    test_cases = [
        ("Jupiter", "Neptune", [5, 6]), # Saturn (5), Uranus (6)
        ("Earth", "Mercury", [1]),      # Venus (1)
        ("Mercury", "Uranus", [1, 2, 3, 4, 5]),
        ("Neptune", "Venus", [2, 3, 4, 5, 6]),
        ("Earth", "Earth", []),          # Same planet -> empty
        ("Mars", "Earth", []),           # Same planet (order handled by sorting) -> empty
        ("Jupiter", "Makemake", []),     # Invalid planet name -> empty (Makemake doesn't exist in 8-bit lookup)
        ("Neptune", "Makemake", [])      # Invalid
    ]

    passed = 0
    failed = 0

    for p1_name, p2_name, expected_indices in test_cases:
        cocotb.log.info(f"Testing {p1_name} vs {p2_name}")
        
        # Map names to integers, handle invalid
        p1_int = planet_map.get(p1_name, 10) # 10 is invalid (>7)
        p2_int = planet_map.get(p2_name, 10)

        # Set inputs
        dut.p1.value = clamp_to_width(p1_int, 3)
        dut.p2.value = clamp_to_width(p2_int, 3)

        # Trigger
        if has_signal(dut, 'clk'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            await wait_for_done(dut)
        else:
            # Combinational -> wait small amount for propagation
            await Timer(1, units='ns')

        # Read output
        raw_result = int(dut.result.value)
        
        # If inputs were invalid or no planets found, result should be 0xFFFFFFFFFFFFFFFF
        expected_empty = (p1_int == p2_int) or (p1_int > 7) or (p2_int > 7) or len(expected_indices) == 0
        
        if expected_empty:
            # Check for all 1s (0xFF per byte)
            # Python int: raw_result should equal (2**64 - 1)
            expected_val = (1 << 64) - 1
            if raw_result != expected_val:
                cocotb.log.error(f"FAIL: {p1_name}/{p2_name}. Expected empty mask {expected_val:x}, got {raw_result:x}")
                failed += 1
            else:
                passed += 1
        else:
            # Check packed result
            # Convert expected indices to bytes
            packed = pack_bytes(expected_indices)
            
            if raw_result != packed:
                cocotb.log.error(f"FAIL: {p1_name}/{p2_name}. Expected packed {packed:x}, got {raw_result:x}")
                # Debug log
                for i in range(8):
                    byte = (raw_result >> (i*8)) & 0xFF
                    if byte != 0xFF:
                        cocotb.log.info(f"  Slot {i}: {byte}")
                failed += 1
            else:
                passed += 1

    if failed:
        raise TestFailure(f"{failed} tests failed")
    else:
        cocotb.log.info(f"All {passed} tests passed")