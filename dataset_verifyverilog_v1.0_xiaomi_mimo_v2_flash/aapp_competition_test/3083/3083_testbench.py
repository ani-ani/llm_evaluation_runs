import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
MAX_SONGS = 100
MAX_NEIGHBORS = 40
CLK_PERIOD_NS = 10
MAX_CYCLES = 100000

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    """Safely convert cocotb value to int, returning default if X/Z."""
    try:
        return int(value)
    except ValueError:
        return default

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY WRITE HELPERS
# ============================================================================

async def write_array(dut, array_name, values, element_width):
    """Write values to array, handling different interface styles."""
    # Try 2D array first
    try:
        arr = getattr(dut, array_name)
        for i, val in enumerate(values):
            if i < len(values):
                arr[i].value = clamp_to_width(val, element_width)
        return
    except (AttributeError, TypeError):
        pass
    
    # Try individual ports (arr_0, arr_1, ...)
    for i, val in enumerate(values):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(val, element_width)
        else:
            raise TestFailure(f"Cannot find array port: {array_name}[{i}] or {port_name}")

async def write_2d_array(dut, array_name, values_2d, element_width):
    """Write 2D array values."""
    # Try to write 2D array
    try:
        arr = getattr(dut, array_name)
        for i, row in enumerate(values_2d):
            for j, val in enumerate(row):
                if j < len(row):
                    arr[i][j].value = clamp_to_width(val, element_width)
        return
    except (AttributeError, TypeError):
        pass
    
    # Fallback: assume individual ports for each element
    for i, row in enumerate(values_2d):
        for j, val in enumerate(row):
            port_name = f"{array_name}_{i}_{j}"
            if has_signal(dut, port_name):
                getattr(dut, port_name).value = clamp_to_width(val, element_width)
            else:
                # Try indexed access
                try:
                    getattr(dut, array_name)[i][j].value = clamp_to_width(val, element_width)
                except:
                    raise TestFailure(f"Cannot write {array_name}[{i}][{j}]")

async def read_array(dut, array_name, size):
    """Read array values."""
    results = []
    try:
        arr = getattr(dut, array_name)
        for i in range(size):
            if is_value_defined(arr[i].value):
                results.append(int(arr[i].value))
            else:
                results.append(None)
        return results
    except (AttributeError, TypeError):
        pass
    
    for i in range(size):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            val = getattr(dut, port_name).value
            if is_value_defined(val):
                results.append(int(val))
            else:
                results.append(None)
        else:
            results.append(None)
    return results

# ============================================================================
# SEQUENTIAL HELPERS
# ============================================================================

async def reset_dut(dut):
    """Reset the DUT."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_find_playlist(dut):
    """Test the find_playlist module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Test cases from problem
    test_inputs = [
        # Test case 1: Expected success
        [
            "10",
            "a 2 10 3",
            "b 1 6",
            "c 2 1 5",
            "d 1 9",
            "e 1 4",
            "f 1 2",
            "g 2 6 8",
            "h 0",
            "i 1 3",
            "j 1 7"
        ],
        # Test case 2: Same artist in consecutive songs - should fail
        [
            "10",
            "a 2 10 3",
            "a 1 6",
            "c 2 1 5",
            "d 1 9",
            "e 1 4",
            "f 1 2",
            "g 2 6 8",
            "h 0",
            "i 1 3",
            "j 1 7"
        ],
        # Test case 3: Another fail case
        [
            "10",
            "a 2 10 3",
            "b 1 6",
            "c 2 1 5",
            "d 1 9",
            "e 1 9",
            "f 1 2",
            "g 2 6 8",
            "h 0",
            "i 1 3",
            "j 1 7"
        ]
    ]
    
    expected_outputs = [
        [5, 4, 9, 3, 1, 10, 7, 6, 2],  # Test 1: success
        None,  # Test 2: fail
        None,  # Test 3: fail
    ]
    
    for test_idx, (input_strs, expected) in enumerate(zip(test_inputs, expected_outputs)):
        dut._log.info(f"\nRunning Test Case {test_idx+1}")
        
        # Parse input
        n = int(input_strs[0])
        songs = []
        artist_list = []
        neighbors_list = []
        
        for i in range(1, n+1):
            parts = input_strs[i].split()
            artist = parts[0]
            t = int(parts[1])
            neighbors = [int(x)-1 for x in parts[2:2+t]] if t > 0 else []
            
            artist_list.append(artist)
            songs.append((artist, neighbors))
            neighbors_list.append(neighbors)
        
        # Map artists to indices
        artist_to_idx = {}
        idx = 0
        artist_indices = []
        for artist in artist_list:
            if artist not in artist_to_idx:
                artist_to_idx[artist] = idx
                idx += 1
            artist_indices.append(artist_to_idx[artist])
        
        # Prepare arrays for the DUT
        neighbor_count = [len(n) for n in neighbors_list]
        
        # Pad neighbors to MAX_NEIGHBORS
        neighbors_padded = []
        for n_list in neighbors_list:
            padded = n_list[:MAX_NEIGHBORS] + [0] * (MAX_NEIGHBORS - len(n_list))
            neighbors_padded.append(padded)
        
        # Reset DUT
        await reset_dut(dut)
        
        # Write input data
        dut.n.value = n
        
        # Write artist indices
        for i in range(MAX_SONGS):
            if i < n:
                if has_signal(dut, f'artist_idx_{i}'):
                    getattr(dut, f'artist_idx_{i}').value = artist_indices[i]
                else:
                    dut.artist_idx[i].value = artist_indices[i]
            else:
                if has_signal(dut, f'artist_idx_{i}'):
                    getattr(dut, f'artist_idx_{i}').value = 0
                else:
                    dut.artist_idx[i].value = 0
        
        # Write neighbor counts
        for i in range(MAX_SONGS):
            if i < n:
                if has_signal(dut, f'neighbor_count_{i}'):
                    getattr(dut, f'neighbor_count_{i}').value = neighbor_count[i]
                else:
                    dut.neighbor_count[i].value = neighbor_count[i]
            else:
                if has_signal(dut, f'neighbor_count_{i}'):
                    getattr(dut, f'neighbor_count_{i}').value = 0
                else:
                    dut.neighbor_count[i].value = 0
        
        # Write neighbors 2D array
        for i in range(MAX_SONGS):
            for j in range(MAX_NEIGHBORS):
                if i < n and j < len(neighbors_padded[i]):
                    port_name = f'neighbors_{i}_{j}'
                    if has_signal(dut, port_name):
                        getattr(dut, port_name).value = neighbors_padded[i][j]
                    else:
                        try:
                            dut.neighbors[i][j].value = neighbors_padded[i][j]
                        except:
                            pass
                else:
                    port_name = f'neighbors_{i}_{j}'
                    if has_signal(dut, port_name):
                        getattr(dut, port_name).value = 0
                    else:
                        try:
                            dut.neighbors[i][j].value = 0
                        except:
                            pass
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        await wait_for_done(dut)
        
        # Read result
        if not is_value_defined(dut.found.value):
            raise TestFailure(f"Test {test_idx+1}: found signal is undefined")
        
        found = int(dut.found.value)
        
        if expected is None:
            # Expected failure
            if found != 0:
                raise TestFailure(f"Test {test_idx+1}: Expected failure but found=1")
            dut._log.info(f"  PASS: Correctly returned fail")
        else:
            # Expected success
            if found != 1:
                raise TestFailure(f"Test {test_idx+1}: Expected success but found=0")
            
            # Read path
            path = []
            for i in range(9):
                port_name = f'path_{i}'
                if has_signal(dut, port_name):
                    val = getattr(dut, port_name).value
                else:
                    val = dut.path[i].value
                
                if is_value_defined(val):
                    path.append(int(val) + 1)  # Convert to 1-indexed
                else:
                    raise TestFailure(f"Test {test_idx+1}: Path[{i}] is undefined")
            
            # Verify path
            if path != expected:
                raise TestFailure(f"Test {test_idx+1}: Expected {expected}, got {path}")
            
            dut._log.info(f"  PASS: Found valid playlist: {path}")
    
    dut._log.info("\nAll tests completed successfully")