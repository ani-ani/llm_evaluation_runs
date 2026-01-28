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

# Fixed point helpers (Q16.16)
FRAC_BITS = 16

def float_to_fixed(f):
    return int(f * (1 << FRAC_BITS))

def fixed_to_float(v):
    # Handle signed values
    if v & (1 << 31): # Assuming 32-bit
        return (v - (1 << 32)) / (1 << FRAC_BITS)
    return v / (1 << FRAC_BITS)

# Testbench
DATA_WIDTH = 16
CLK_NS = 10
MAX_CYCLES = 5000

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_bulkheads(dut):
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    else:
        raise TestFailure("Module must have 'clk' signal")

    # Reset
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 0
        if has_signal(dut, 'start'): dut.start.value = 0
        if has_signal(dut, 'vertex_valid'): dut.vertex_valid.value = 0
        if has_signal(dut, 'vertex_done'): dut.vertex_done.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        raise TestFailure("Module must have 'rst_n' signal")

    # Test Cases
    test_cases = [
        {
            "min_area": 50,
            "vertices": [(110, 10), (80, 10), (80, 0), (110, 0)],
            "expected_M": 6,
            "expected_xs": [85, 90, 95, 100, 105]
        },
        {
            "min_area": 24,
            "vertices": [(10, 10), (30, 10), (20, 20)],
            "expected_M": 4,
            "expected_xs": [17.071067, 20, 22.928932]
        },
        {
            "min_area": 1280,
            "vertices": [(100, 120), (97, 50), (94, 99), (74, 97), (50, 87), (29, 71), (13, 50), (3, 26), (0, 0), (100, 0)],
            "expected_M": 6,
            "expected_xs": [27.5015466, 44.3204382, 59.0041321, 72.7008423, 85.8494453]
        }
    ]

    for tc in test_cases:
        cocotb.log.info(f"Running test case: Min Area={tc['min_area']}, Vertices={len(tc['vertices'])}")
        
        # Reset for new test case
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

        # 1. Send inputs
        # Set min_area (assuming input is 32-bit fixed point)
        dut.min_area.value = float_to_fixed(tc['min_area'])
        
        # Stream vertices
        if has_signal(dut, 'vertex_valid'):
            for x, y in tc['vertices']:
                dut.vertex_x.value = from_signed(x, DATA_WIDTH)
                dut.vertex_y.value = from_signed(y, DATA_WIDTH)
                dut.vertex_valid.value = 1
                await RisingEdge(dut.clk)
            dut.vertex_valid.value = 0
        
        if has_signal(dut, 'vertex_done'):
            dut.vertex_done.value = 1
            await RisingEdge(dut.clk)
            dut.vertex_done.value = 0

        # 2. Start processing
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
        
        # 3. Wait for output
        max_sections = 0
        if has_signal(dut, 'max_sections'):
            await RisingEdge(dut.clk)
            # Wait until busy goes low or result appears, or timeout
            # The module outputs count first usually, or we wait for done
            
            # Wait for result_valid to go high for the first output or check count
            # Let's assume max_sections is available after processing starts
            # We wait for a few cycles or until result_done
            
            # Check if result_valid pulses
            results = []
            for _ in range(MAX_CYCLES):
                if is_value_defined(dut.result_valid.value) and int(dut.result_valid.value) == 1:
                    val = int(dut.result.value)
                    # Interpret as signed 32-bit fixed point
                    # Since Python int is unbounded, handle the sign manually for conversion
                    if val >= (1 << 31):
                        val = val - (1 << 32)
                    results.append(val / (1 << FRAC_BITS))
                    
                if is_value_defined(dut.result_done.value) and int(dut.result_done.value) == 1:
                    break
                
                # Check max_sections if it updates continuously
                if is_value_defined(dut.max_sections.value):
                    current_max = int(dut.max_sections.value)
                    if current_max > 0:
                        max_sections = current_max
                
                await RisingEdge(dut.clk)
            
            # Verify Max Sections
            if max_sections != tc['expected_M']:
                raise TestFailure(f"Expected M={tc['expected_M']}, got {max_sections}")
            
            # Verify Results count
            if len(results) != len(tc['expected_xs']):
                raise TestFailure(f"Expected {len(tc['expected_xs'])} results, got {len(results)}")
            
            # Verify Result Values (within tolerance)
            for i, (actual, expected) in enumerate(zip(results, tc['expected_xs'])):
                diff = abs(actual - expected)
                if diff > 0.001:
                    raise TestFailure(f"Result {i}: Expected {expected}, got {actual} (diff {diff})")
            
            cocotb.log.info(f"Test passed: M={max_sections}, Xs={results}")
        else:
             raise TestFailure("Module missing 'max_sections' output")