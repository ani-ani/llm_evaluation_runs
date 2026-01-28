import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 16
MAX_CYCLES = 2000
CLK_NS = 10

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
    if has_signal(dut, 'config_valid'): dut.config_valid.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def read_results(dut, num_molecules):
    coeffs = []
    # Assuming a sequential interface where we toggle index or it auto-increments
    # Here we assume writing to molecule_idx triggers output for that index
    # Or the module streams output. We will assume we need to request each coefficient.
    # However, the prompt says "coeff_out for the current molecule index".
    # Let's assume we set molecule_idx and wait for result_valid.
    for i in range(num_molecules):
        dut.molecule_idx.value = i
        await RisingEdge(dut.clk)
        # Wait for result_valid if necessary, or assume combinational/latency
        # For robust testing, let's wait a few cycles or check a valid signal
        for _ in range(10): # Small wait for valid
            await RisingEdge(dut.clk)
            if is_value_defined(dut.result_valid.value) and int(dut.result_valid.value) == 1:
                coeffs.append(int(dut.coeff_out.value))
                break
        else:
             # If no valid signal, just grab value (risky but might be combinational)
             coeffs.append(int(dut.coeff_out.value))
    return coeffs

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_stoichiometry(dut):
    # Setup Clock
    clock = Clock(dut.clk, CLK_NS, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    # Test Case 1: H2O + CO2 -> O2 + C6H12O6
    # +1 2 H 2 O 1
    # +1 2 C 1 O 2
    # -1 1 O 2
    # -1 3 C 6 H 12 O 6
    # Expected: 6 6 6 1
    
    # Input Format: list of tuples (sign, elements)
    # elements is list of (element_id, count)
    # We map element names to IDs: H=0, O=1, C=2
    
    test_cases = [
        {
            "molecules": [
                (+1, [(0, 2), (1, 1)]), # H2O
                (+1, [(2, 1), (1, 2)]), # CO2
                (-1, [(1, 2)]),          # O2
                (-1, [(2, 6), (0, 12), (1, 6)]) # C6H12O6
            ],
            "expected": [6, 6, 6, 1]
        },
        # Test Case 2 from prompt (simplified mapping)
        # +1 5 Be 2 C 1 O 3 O 2 H 2  -> Be2C1O5H2 (Note: input has O 3 O 2 -> O 5)
        # +1 3 Ac 1 O 1 H 1          -> Ac1O1H1
        # -1 4 Be 4 O 1 Ac 6 O 6     -> Be4O7Ac6 (O 1 O 6 -> O 7)
        # -1 2 H 2 O 1               -> H2O
        # -1 2 C 1 O 2               -> CO2
        # Expected: 2 6 1 5 2
        {
            "molecules": [
                (+1, [(0, 2), (1, 1), (2, 5)]), # Be=0, C=1, O=2, H=3, Ac=4. Wait input has Be C O H.
                # Let's map strictly based on order of appearance in test case 2 for unique elements.
                # Elements: Be, C, O, H, Ac. 
                (+1, [(0, 2), (1, 1), (2, 5), (3, 2)]), # Be2C1O5H2 (Input: +1 5 Be 2 C 1 O 3 O 2 H 2)
                (+1, [(4, 1), (2, 1), (3, 1)]),          # Ac1O1H1 (Input: +1 3 Ac 1 O 1 H 1)
                (-1, [(0, 4), (2, 7), (4, 6)]),          # Be4O7Ac6 (Input: -1 4 Be 4 O 1 Ac 6 O 6)
                (-1, [(3, 2), (2, 1)]),                  # H2O (Input: -1 2 H 2 O 1)
                (-1, [(1, 1), (2, 2)]),                  # CO2 (Input: -1 2 C 1 O 2)
            ],
            "expected": [2, 6, 1, 5, 2]
        }
    ]

    for case_idx, case in enumerate(test_cases):
        cocotb.log.info(f"Running Test Case {case_idx + 1}")
        
        # 1. Configuration Phase
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Feed molecules
        molecules = case["molecules"]
        num_molecules = len(molecules)
        num_unique_elements = 0
        # Map element IDs to sequential 0..N
        element_map = {}
        next_elem_id = 0
        
        for i, (sign, elems) in enumerate(molecules):
            dut.config_valid.value = 1
            dut.molecule_idx.value = i
            dut.sign.value = 1 if sign == 1 else 0 # Assuming 1=left, 0=right
            dut.num_elements.value = len(elems)
            
            for elem_str, count in elems:
                # Map the element string (we used ints in test data, but let's pretend they are strings or mapped ints)
                # In this python test, we used integers 0..4 for elements. 
                # The Verilog expects element_id 0..9.
                dut.element_id.value = elem_str
                dut.count.value = count
                await RisingEdge(dut.clk)
            
            # End of molecule marker if needed, or just next cycle
        
        dut.config_valid.value = 0
        await RisingEdge(dut.clk)
        
        # 2. Solution Phase
        # Wait for done
        await wait_for_done(dut)
        
        # 3. Verification
        # Read results
        coeffs = []
        for i in range(num_molecules):
            dut.molecule_idx.value = i
            await RisingEdge(dut.clk) # Latch index
            # Assume result_valid asserts after 1 cycle or combinational
            # Let's wait for result_valid to be safe
            valid_found = False
            for _ in range(10):
                await RisingEdge(dut.clk)
                if is_value_defined(dut.result_valid.value) and int(dut.result_valid.value) == 1:
                    coeffs.append(int(dut.coeff_out.value))
                    valid_found = True
                    break
            if not valid_found:
                # Fallback if no valid signal exists
                coeffs.append(int(dut.coeff_out.value))
        
        if coeffs != case["expected"]:
            raise TestFailure(f"Case {case_idx+1}: Expected {case['expected']}, got {coeffs}")
        else:
            cocotb.log.info(f"Case {case_idx+1} Passed: {coeffs}")
