import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import re

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
MAX_STR_LEN = 16
NUM_VARS = 4
MAX_NESTING = 2
CLK_PERIOD_NS = 10

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

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

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

def pack_string(s, max_len=MAX_STR_LEN):
    """Pack string into fixed-width integer (LSB first)."""
    result = 0
    for i, c in enumerate(s[:max_len]):
        result |= ord(c) << (i * DATA_WIDTH)
    return result, len(s)

def unpack_string(data, length):
    """Unpack integer to string."""
    chars = []
    for i in range(length):
        char = (data >> (i * DATA_WIDTH)) & 0xFF
        if char != 0:
            chars.append(chr(char))
    return ''.join(chars)

# ============================================================================
# PARSER: Converts NenScript to microcode
# ============================================================================

def parse_nenscript(script):
    """Parse NenScript and return list of commands."""
    commands = []
    variables = {}  # name -> index
    var_counter = 0
    
    lines = script.strip().split('\n')
    
    for line in lines:
        line = line.strip()
        if line == 'end.':
            commands.append(('END', None, None, None, None, None))
            break
            
        # Variable declaration: var <name> = <value>;
        if line.startswith('var '):
            # Extract name and value
            match = re.match(r'var\s+(\w+)\s*=\s*(.+);', line)
            if match:
                name, value = match.groups()
                value = value.strip()
                
                # Assign variable index
                if name not in variables:
                    variables[name] = var_counter
                    var_counter += 1
                    if var_counter > NUM_VARS:
                        raise ValueError(f"Too many variables (max {NUM_VARS})")
                idx = variables[name]
                
                # Parse value expression
                if value.startswith('"') and value.endswith('"'):
                    # String literal
                    literal = value[1:-1]
                    if len(literal) > MAX_STR_LEN:
                        literal = literal[:MAX_STR_LEN]
                    data, length = pack_string(literal)
                    commands.append(('LOAD', idx, None, data, length, None, None, None))
                    
                elif value in variables:
                    # Variable reference
                    src_idx = variables[value]
                    commands.append(('COPY', idx, src_idx, None, None, None, None, None))
                    
                elif value.startswith('`') and value.endswith('`'):
                    # Template literal
                    template = value[1:-1]
                    
                    # Parse template parts
                    parts = []
                    current = ''
                    i = 0
                    while i < len(template):
                        if template[i:i+2] == '${':
                            if current:
                                parts.append(('literal', current))
                                current = ''
                            # Find closing }
                            end_brace = template.find('}', i+2)
                            if end_brace == -1:
                                raise ValueError("Unclosed ${}")
                            embedded = template[i+2:end_brace]
                            parts.append(('var', embedded))
                            i = end_brace + 1
                        else:
                            current += template[i]
                            i += 1
                    if current:
                        parts.append(('literal', current))
                    
                    # Simplify: assume pattern prefix + var + suffix
                    prefix = ''
                    suffix = ''
                    var_name = None
                    
                    for ptype, pval in parts:
                        if ptype == 'literal' and var_name is None:
                            prefix = pval
                        elif ptype == 'var':
                            var_name = pval
                        elif ptype == 'literal' and var_name is not None:
                            suffix = pval
                    
                    if var_name not in variables:
                        raise ValueError(f"Variable {var_name} not defined")
                    
                    var_idx = variables[var_name]
                    prefix_data, prefix_len = pack_string(prefix)
                    suffix_data, suffix_len = pack_string(suffix)
                    
                    # First concatenate, then assign to idx
                    # For simplicity, we'll do CONCAT to build the string
                    commands.append(('CONCAT', idx, var_idx, None, None, prefix_data, prefix_len, suffix_data, suffix_len))
                    
        # Print statement: print <expr>;
        elif line.startswith('print '):
            match = re.match(r'print\s+(.+);', line)
            if match:
                value = match.groups()[0]
                value = value.strip()
                
                if value in variables:
                    # Print variable
                    idx = variables[value]
                    commands.append(('PRINT_VAR', idx, None, None, None, None, None, None))
                    
                elif value.startswith('`') and value.endswith('`'):
                    # Print template
                    template = value[1:-1]
                    # Parse same as above
                    parts = []
                    current = ''
                    i = 0
                    while i < len(template):
                        if template[i:i+2] == '${':
                            if current:
                                parts.append(('literal', current))
                                current = ''
                            end_brace = template.find('}', i+2)
                            embedded = template[i+2:end_brace]
                            parts.append(('var', embedded))
                            i = end_brace + 1
                        else:
                            current += template[i]
                            i += 1
                    if current:
                        parts.append(('literal', current))
                    
                    prefix = ''
                    suffix = ''
                    var_name = None
                    
                    for ptype, pval in parts:
                        if ptype == 'literal' and var_name is None:
                            prefix = pval
                        elif ptype == 'var':
                            var_name = pval
                        elif ptype == 'literal' and var_name is not None:
                            suffix = pval
                    
                    if var_name not in variables:
                        raise ValueError(f"Variable {var_name} not defined")
                    
                    var_idx = variables[var_name]
                    prefix_data, prefix_len = pack_string(prefix)
                    suffix_data, suffix_len = pack_string(suffix)
                    
                    commands.append(('PRINT_TEMPLATE', var_idx, None, None, None, prefix_data, prefix_len, suffix_data, suffix_len))
    
    return commands

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_nenscript_processor(dut):
    """Test the NenScript processor with sample inputs."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_inputs = [
        """var a = \"Gon\";
var b = a;
var c = `My name is ${a}`;
print c;
print `My name is ${b}`;
end.""",
        """var one = \"1\";
var two = \"2\";
var three = \"3\";
print `${one} + ${two} = ${three}`;
print `1${`2${three}2`}1`;
end."""
    ]
    
    expected_outputs = [
        "My name is Gon",
        "My name is Gon",
        "1 + 2 = 3",
        "12321"
    ]
    
    # We need to track which print outputs correspond to which test case
    # For simplicity, we'll run each test case separately
    
    for test_idx, script in enumerate(test_inputs):
        dut._log.info(f"Test case {test_idx+1}")
        
        try:
            commands = parse_nenscript(script)
            dut._log.info(f"Generated {len(commands)} commands")
            
            output_index = 0
            
            for cmd in commands:
                cmd_type = cmd[0]
                
                if cmd_type == 'END':
                    break
                
                # Prepare command inputs
                if cmd_type == 'LOAD':
                    dut.cmd_type.value = 0
                    dut.var_idx.value = cmd[1]
                    dut.literal_data.value = cmd[3]
                    dut.literal_len.value = cmd[4]
                elif cmd_type == 'COPY':
                    dut.cmd_type.value = 1
                    dut.var_idx.value = cmd[1]
                    dut.var_idx2.value = cmd[2]
                elif cmd_type == 'CONCAT':
                    dut.cmd_type.value = 2
                    dut.var_idx.value = cmd[1]
                    dut.var_idx2.value = cmd[2]
                    dut.prefix_data.value = cmd[5]
                    dut.prefix_len.value = cmd[6]
                    dut.suffix_data.value = cmd[7]
                    dut.suffix_len.value = cmd[8]
                elif cmd_type == 'PRINT_VAR':
                    dut.cmd_type.value = 3
                    dut.var_idx.value = cmd[1]
                elif cmd_type == 'PRINT_TEMPLATE':
                    dut.cmd_type.value = 3
                    dut.var_idx.value = cmd[1]
                    dut.prefix_data.value = cmd[5]
                    dut.prefix_len.value = cmd[6]
                    dut.suffix_data.value = cmd[7]
                    dut.suffix_len.value = cmd[8]
                else:
                    continue
                
                # Pulse start
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                timeout = 100
                for _ in range(timeout):
                    await RisingEdge(dut.clk)
                    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                        break
                else:
                    raise TestFailure(f"Timeout waiting for done")
                
                # Handle print output
                if cmd_type in ['PRINT_VAR', 'PRINT_TEMPLATE']:
                    if is_value_defined(dut.print_valid.value) and int(dut.print_valid.value) == 1:
                        print_data = int(dut.print_data.value)
                        print_len = int(dut.print_len.value)
                        output_str = unpack_string(print_data, print_len)
                        
                        if output_index < len(expected_outputs):
                            expected = expected_outputs[output_index]
                            if output_str != expected:
                                raise TestFailure(f"Output mismatch: expected '{expected}', got '{output_str}'")
                            dut._log.info(f"  PASS: '{output_str}'")
                            output_index += 1
                        else:
                            raise TestFailure(f"Unexpected output: '{output_str}'")
                    else:
                        raise TestFailure("Print valid not asserted")
                
                await RisingEdge(dut.clk)
            
        except Exception as e:
            dut._log.error(f"Test failed: {e}")
            raise
    
    dut._log.info("All tests passed!")
