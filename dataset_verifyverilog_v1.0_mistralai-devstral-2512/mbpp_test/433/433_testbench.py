import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# --- Helper Functions ---
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

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    if v < 0: return 0
    return v if v <= max_val else max_val

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    if has_signal(dut, 'valid_in'):
        dut.valid_in.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# --- Testbench ---
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_check_greater(dut):
    # Parameters based on problem constraints
    DATA_WIDTH = 8
    NUMBER_WIDTH = 16
    ARRAY_SIZE = 8
    CLK_NS = 10
    
    # Setup Clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test Cases
    # Format: (Array_Values, Number, Expected_Result, Description)
    test_cases = [
        ([1, 2, 3, 4, 5, 0, 0, 0], 4, 0, "Number equals max (partial array)"),
        ([2, 3, 4, 5, 6, 0, 0, 0], 8, 1, "Number greater than max (partial array)"),
        ([9, 7, 4, 8, 6, 1, 0, 0], 11, 1, "Number greater than all (partial array)"),
        ([10, 10, 10, 10, 10, 10, 10, 10], 10, 0, "Number equals all elements"),
        ([1, 1, 1, 1, 1, 1, 1, 1], 0, 0, "Number less than all elements")
    ]
    
    passed = 0
    failed = 0
    
    for i, (arr_vals, number, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        
        # Pad array to full size (8 elements) with 0 if needed
        full_arr = arr_vals + [0] * (ARRAY_SIZE - len(arr_vals))
        
        try:
            # Write Inputs
            # 1. Write Array Elements (Individual assignment is crucial)
            for j in range(ARRAY_SIZE):
                if has_signal(dut, f'arr_{j}'):
                    val = full_arr[j]
                    getattr(dut, f'arr_{j}').value = clamp_to_width(val, DATA_WIDTH)
                elif has_signal(dut, 'arr'):
                     # Handle packed array case if necessary, though prompt specifies individual signals
                     val = full_arr[j]
                     dut.arr[j].value = clamp_to_width(val, DATA_WIDTH)

            # 2. Write Number
            dut.number.value = clamp_to_width(number, NUMBER_WIDTH)
            
            # 3. Pulse Start and Valid
            dut.valid_in.value = 1
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            dut.valid_in.value = 0 # Pulse valid, or keep high if inputs stable? 
                                   # Prompt implies pulse or stable. We'll assume valid needs to be high.
                                   # To be safe, we keep valid high until done or follow spec.
                                   # The prompt says `valid_in` indicates values are ready. 
                                   # If sequential logic latches, we might only need it during start.
                                   # If combinational, we need it constantly. Let's assume standard latch-on-start logic.
                                   # However, standard practice is to deassert start and valid after one cycle.
            
            # Wait for Done
            await wait_for_done(dut)
            
            # Read Output
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal is undefined (X or Z)")
            
            result_val = int(dut.result.value)
            
            if result_val != expected:
                raise TestFailure(f"Expected {expected}, got {result_val}")
                
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: Test {i+1} ({desc}) - {e}")
            failed += 1
            
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed, {passed} passed")
    else:
        cocotb.log.info(f"All {passed} tests passed!")
