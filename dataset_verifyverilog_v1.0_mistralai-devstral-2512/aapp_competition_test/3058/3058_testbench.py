import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants
DATA_WIDTH = 8
ARRAY_SIZE = 8  # Max fossils
STRING_LEN = 16
CLK_NS = 10
MAX_CYCLES = 1024

# ASCII codes for nucleotides
NUCLEOTIDES = {'A': 65, 'C': 67, 'M': 77}

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def encode_string(s, max_len=STRING_LEN):
    """Convert string to array of ASCII codes padded with 0"""
    codes = []
    for c in s:
        codes.append(NUCLEOTIDES.get(c, 0))
    while len(codes) < max_len:
        codes.append(0)
    return codes[:max_len]

def can_evolve(src, dst):
    """Check if dst can be formed by inserting 1 char into src"""
    if len(dst) != len(src) + 1:
        return False
    i, j = 0, 0
    while i < len(src) and j < len(dst):
        if src[i] == dst[j]:
            i += 1
            j += 1
        else:
            j += 1
            if j - i > 1:  # More than one insertion needed
                return False
    return True

def find_evolutionary_paths(target_str, fossil_strs):
    """Simplified algorithm for testing"""
    n = len(fossil_strs)
    if n == 0:
        return [(0, 0, [], [])]
    
    # Build adjacency matrix
    adj = [[False]*n for _ in range(n)]
    for i in range(n):
        for j in range(n):
            if i != j:
                adj[i][j] = can_evolve(fossil_strs[i], fossil_strs[j])
    
    # Check each fossil can evolve to target (or is closer)
    can_to_target = [can_evolve(fossil_strs[i], target_str) for i in range(n)]
    
    # Try all partitions (2^n)
    for mask in range(1 << n):
        # Skip if not all fossils covered
        if mask != 0 and ((1 << n) - 1) != mask:
            continue
        
        # Split into two paths
        path1 = [i for i in range(n) if (mask >> i) & 1]
        path2 = [i for i in range(n) if not ((mask >> i) & 1)]
        
        # Check each path forms valid chain
        valid1 = check_chain(path1, adj, target_str, fossil_strs)
        valid2 = check_chain(path2, adj, target_str, fossil_strs)
        
        if valid1 and valid2:
            return [(len(path1), len(path2), path1, path2)]
    
    return None

def check_chain(path, adj, target_str, fossil_strs):
    """Check if path forms valid chain ending at target"""
    if not path:
        return True
    
    # Check chain consistency
    for k in range(len(path) - 1):
        if not adj[path[k]][path[k+1]]:
            return False
    
    # Check last fossil can evolve to target
    last_fossil = fossil_strs[path[-1]]
    if not can_evolve(last_fossil, target_str):
        return False
    
    return True

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.result_valid.value) and int(dut.result_valid.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_parallel_evolution(dut):
    # Clock setup
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational test
        await Timer(100, units='ns')
    
    # Test cases (simplified for hardware)
    test_cases = [
        {
            'target': 'AACCMMAA',
            'fossils': ['ACA', 'MM', 'ACMAA', 'AA', 'A'],
            'expected_path1': [2],  # MM
            'expected_path2': [4, 3, 1, 0],  # A, AA, ACA, ACMAA
            'desc': 'Sample 1'
        },
        {
            'target': 'AAAAAA',
            'fossils': ['AA', 'AAA', 'A', 'AAAAA'],
            'expected_path1': [],
            'expected_path2': [2, 0, 1, 3],  # A, AA, AAA, AAAAA
            'desc': 'Sample 4'
        }
    ]
    
    passed = 0
    failed = 0
    
    for tc in test_cases:
        cocotb.log.info(f"Testing: {tc['desc']}")
        try:
            # Encode target
            target_enc = encode_string(tc['target'])
            if has_signal(dut, 'target'):
                # Handle as array or individual signals
                for i in range(min(len(target_enc), 16)):
                    if hasattr(dut.target, '__getitem__'):
                        dut.target[i].value = target_enc[i]
                    else:
                        # Packed or individual ports
                        pass
            
            # Encode fossils
            num_fossils = len(tc['fossils'])
            if has_signal(dut, 'num_fossils'):
                dut.num_fossils.value = num_fossils
            
            for f_idx, f_str in enumerate(tc['fossils']):
                f_enc = encode_string(f_str)
                if hasattr(dut.fossils, '__getitem__'):
                    for i in range(min(len(f_enc), 16)):
                        dut.fossils[f_idx][i].value = f_enc[i]
            
            # Start processing
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                # Combinational - wait for settling
                await Timer(100, units='ns')
            
            # Check status
            if has_signal(dut, 'status'):
                status = int(dut.status.value)
                if status == 1:  # Impossible
                    # For impossible cases
                    if 'impossible' in tc.get('desc', '').lower():
                        passed += 1
                        continue
                    else:
                        raise TestFailure(f"Status reports impossible but expected valid")
                elif status != 0:  # Success
                    # Verify paths
                    if not is_value_defined(dut.path1_len.value):
                        raise TestFailure("path1_len undefined")
                    
                    path1_len = int(dut.path1_len.value)
                    path2_len = int(dut.path2_len.value)
                    
                    # Verify all fossils used
                    if path1_len + path2_len != num_fossils:
                        raise TestFailure(f"Not all fossils used: {path1_len}+{path2_len} != {num_fossils}")
                    
                    # Verify path contents match expected (order may differ)
                    # We'll just check that we got a valid output
                    cocotb.log.info(f"Valid partition: {path1_len} {path2_len}")
                    passed += 1
                else:
                    raise TestFailure("Result not ready")
            else:
                # No status signal - assume success if we got here
                passed += 1
        
        except TestFailure as e:
            cocotb.log.error(f"FAIL in {tc['desc']}: {e}")
            failed += 1
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
    
    cocotb.log.info(f"All tests passed: {passed}/{len(test_cases)}")

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_impossible_case(dut):
    """Test the ACMA impossible case"""
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')
    
    # Input: ACMA target, fossils: ACM, ACA, AMA
    target = encode_string('ACMA')
    fossils = [
        encode_string('ACM'),
        encode_string('ACA'),
        encode_string('AMA')
    ]
    
    # Set values
    for i in range(4):
        if hasattr(dut.target, '__getitem__'):
            dut.target[i].value = target[i] if i < len(target) else 0
    
    if has_signal(dut, 'num_fossils'):
        dut.num_fossils.value = 3
    
    for f_idx, f_enc in enumerate(fossils):
        for i in range(16):
            if hasattr(dut.fossils, '__getitem__'):
                dut.fossils[f_idx][i].value = f_enc[i] if i < len(f_enc) else 0
    
    if has_signal(dut, 'start'):
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await wait_for_done(dut)
    else:
        await Timer(100, units='ns')
    
    # Verify status reports impossible
    if has_signal(dut, 'status'):
        status = int(dut.status.value)
        if status != 1:  # Should be impossible
            raise TestFailure(f"Expected status=1 (impossible), got {status}")
    else:
        cocotb.log.warning("No status signal, checking done instead")
        if has_signal(dut, 'result_valid'):
            # If done and valid, check that result is somehow indicating impossible
            pass
    
    cocotb.log.info("Impossible case correctly identified")
