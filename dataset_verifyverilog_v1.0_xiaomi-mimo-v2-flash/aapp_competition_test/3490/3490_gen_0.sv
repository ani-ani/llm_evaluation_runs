module witch_dance_collisions (
    input wire clk,
    input wire rst_n,
    input wire start,
    
    // Inputs for up to 16 witches (N <= 16)
    input wire [15:0] x_0, x_1, x_2, x_3, x_4, x_5, x_6, x_7,
    input wire [15:0] x_8, x_9, x_10, x_11, x_12, x_13, x_14, x_15,
    input wire [15:0] y_0, y_1, y_2, y_3, y_4, y_5, y_6, y_7,
    input wire [15:0] y_8, y_9, y_10, y_11, y_12, y_13, y_14, y_15,
    input wire [15:0] r_0, r_1, r_2, r_3, r_4, r_5, r_6, r_7,
    input wire [15:0] r_8, r_9, r_10, r_11, r_12, r_13, r_14, r_15,
    input wire [15:0] valid_i,  // 16-bit mask
    
    // Outputs
    output reg [1:0] result,
    output reg done,
    output reg busy
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] FETCH     = 3'd1;
    localparam [2:0] COMPUTE   = 3'd2;
    localparam [2:0] CHECK     = 3'd3;
    localparam [2:0] FINISH    = 3'd4;
    localparam [2:0] ERROR     = 3'd5;
    
    // Result codes
    localparam [1:0] RESULT_OK      = 2'd0;
    localparam [1:0] RESULT_CRASH   = 2'd1;
    localparam [1:0] RESULT_TIMEOUT = 2'd2;
    localparam [1:0] RESULT_ERROR   = 2'd3;
    
    // Constants
    localparam [7:0] MAX_CYCLES     = 8'd255;
    localparam [31:0] SQUARED_DIST_THRESHOLD = 32'h00000004;  // 1e-6 * 2^32 approx
    localparam [31:0] BROOM_LENGTH_SQUARED = 32'h00040000;    // 4.0 in Q16.16
    localparam [7:0] NUM_WITCHES = 8'd16;
    localparam [7:0] WITCHES_SQ = 8'd136;  // 16*15/2
    
    // Registers
    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    reg [7:0] pair_counter;
    reg [7:0] i_index, j_index;
    reg [15:0] x_curr, y_curr, x_other, y_other;
    reg [31:0] dx, dy, dist_sq;
    reg collision_detected;
    reg valid_pair;
    
    // Temporary registers for computation
    reg [31:0] temp_x, temp_y;
    reg [31:0] mult_temp_a, mult_temp_b;
    reg [31:0] diff_temp_x, diff_temp_y;
    
    // Cosine/Sine LUTs (256 entries, 16-bit each)
    reg [15:0] cos_lut [0:255];
    reg [15:0] sin_lut [0:255];
    
    // Endpoint storage for all witches
    reg [31:0] endpoint_x [0:15];  // Q16.16 format
    reg [31:0] endpoint_y [0:15];  // Q16.16 format
    reg [15:0] active_witch_mask;
    
    // Function to get witch index for given pair
    function [7:0] get_witch_index;
        input [7:0] pair_idx;
        input [7:0] witch_num;
        begin
            // For pair (i,j) with i<j, find i and j for current pair_idx
            // This is a simple lookup - for 16 witches, 136 pairs
            if (witch_num == 0) begin
                case (pair_idx)
                    0: get_witch_index = 0;
                    1: get_witch_index = 0;
                    2: get_witch_index = 0;
                    3: get_witch_index = 0;
                    4: get_witch_index = 0;
                    5: get_witch_index = 0;
                    6: get_witch_index = 0;
                    7: get_witch_index = 0;
                    8: get_witch_index = 0;
                    9: get_witch_index = 0;
                    10: get_witch_index = 0;
                    11: get_witch_index = 0;
                    12: get_witch_index = 0;
                    13: get_witch_index = 0;
                    14: get_witch_index = 0;
                    15: get_witch_index = 0;
                    16: get_witch_index = 0;
                    17: get_witch_index = 0;
                    18: get_witch_index = 0;
                    19: get_witch_index = 0;
                    20: get_witch_index = 0;
                    21: get_witch_index = 0;
                    22: get_witch_index = 0;
                    23: get_witch_index = 0;
                    24: get_witch_index = 0;
                    25: get_witch_index = 0;
                    26: get_witch_index = 0;
                    27: get_witch_index = 0;
                    28: get_witch_index = 0;
                    29: get_witch_index = 0;
                    30: get_witch_index = 0;
                    31: get_witch_index = 0;
                    32: get_witch_index = 0;
                    33: get_witch_index = 0;
                    34: get_witch_index = 0;
                    35: get_witch_index = 0;
                    36: get_witch_index = 0;
                    37: get_witch_index = 0;
                    38: get_witch_index = 0;
                    39: get_witch_index = 0;
                    40: get_witch_index = 0;
                    41: get_witch_index = 0;
                    42: get_witch_index = 0;
                    43: get_witch_index = 0;
                    44: get_witch_index = 0;
                    45: get_witch_index = 0;
                    46: get_witch_index = 0;
                    47: get_witch_index = 0;
                    48: get_witch_index = 0;
                    49: get_witch_index = 0;
                    50: get_witch_index = 0;
                    51: get_witch_index = 0;
                    52: get_witch_index = 0;
                    53: get_witch_index = 0;
                    54: get_witch_index = 0;
                    55: get_witch_index = 0;
                    56: get_witch_index = 0;
                    57: get_witch_index = 0;
                    58: get_witch_index = 0;
                    59: get_witch_index = 0;
                    60: get_witch_index = 0;
                    61: get_witch_index = 0;
                    62: get_witch_index = 0;
                    63: get_witch_index = 0;
                    64: get_witch_index = 0;
                    65: get_witch_index = 0;
                    66: get_witch_index = 0;
                    67: get_witch_index = 0;
                    68: get_witch_index = 0;
                    69: get_witch_index = 0;
                    70: get_witch_index = 0;
                    71: get_witch_index = 0;
                    72: get_witch_index = 0;
                    73: get_witch_index = 0;
                    74: get_witch_index = 0;
                    75: get_witch_index = 0;
                    76: get_witch_index = 0;
                    77: get_witch_index = 0;
                    78: get_witch_index = 0;
                    79: get_witch_index = 0;
                    80: get_witch_index = 0;
                    81: get_witch_index = 0;
                    82: get_witch_index = 0;
                    83: get_witch_index = 0;
                    84: get_witch_index = 0;
                    85: get_witch_index = 0;
                    86: get_witch_index = 0;
                    87: get_witch_index = 0;
                    88: get_witch_index = 0;
                    89: get_witch_index = 0;
                    90: get_witch_index = 0;
                    91: get_witch_index = 0;
                    92: get_witch_index = 0;
                    93: get_witch_index = 0;
                    94: get_witch_index = 0;
                    95: get_witch_index = 0;
                    96: get_witch_index = 0;
                    97: get_witch_index = 0;
                    98: get_witch_index = 0;
                    99: get_witch_index = 0;
                    100: get_witch_index = 0;
                    101: get_witch_index = 0;
                    102: get_witch_index = 0;
                    103: get_witch_index = 0;
                    104: get_witch_index = 0;
                    105: get_witch_index = 0;
                    106: get_witch_index = 0;
                    107: get_witch_index = 0;
                    108: get_witch_index = 0;
                    109: get_witch_index = 0;
                    110: get_witch_index = 0;
                    111: get_witch_index = 0;
                    112: get_witch_index = 0;
                    113: get_witch_index = 0;
                    114: get_witch_index = 0;
                    115: get_witch_index = 0;
                    116: get_witch_index = 0;
                    117: get_witch_index = 0;
                    118: get_witch_index = 0;
                    119: get_witch_index = 0;
                    120: get_witch_index = 0;
                    121: get_witch_index = 0;
                    122: get_witch_index = 0;
                    123: get_witch_index = 0;
                    124: get_witch_index = 0;
                    125: get_witch_index = 0;
                    126: get_witch_index = 0;
                    127: get_witch_index = 0;
                    128: get_witch_index = 0;
                    129: get_witch_index = 0;
                    130: get_witch_index = 0;
                    131: get_witch_index = 0;
                    132: get_witch_index = 0;
                    133: get_witch_index = 0;
                    134: get_witch_index = 0;
                    135: get_witch_index = 0;
                endcase
            end else begin
                case (pair_idx)
                    0: get_witch_index = 1;
                    1: get_witch_index = 2;
                    2: get_witch_index = 3;
                    3: get_witch_index = 4;
                    4: get_witch_index = 5;
                    5: get_witch_index = 6;
                    6: get_witch_index = 7;
                    7: get_witch_index = 8;
                    8: get_witch_index = 9;
                    9: get_witch_index = 10;
                    10: get_witch_index = 11;
                    11: get_witch_index = 12;
                    12: get_witch_index = 13;
                    13: get_witch_index = 14;
                    14: get_witch_index = 15;
                    15: get_witch_index = 2;
                    16: get_witch_index = 3;
                    17: get_witch_index = 4;
                    18: get_witch_index = 5;
                    19: get_witch_index = 6;
                    20: get_witch_index = 7;
                    21: get_witch_index = 8;
                    22: get_witch_index = 9;
                    23: get_witch_index = 10;
                    24: get_witch_index = 11;
                    25: get_witch_index = 12;
                    26: get_witch_index = 13;
                    27: get_witch_index = 14;
                    28: get_witch_index = 15;
                    29: get_witch_index = 3;
                    30: get_witch_index = 4;
                    31: get_witch_index = 5;
                    32: get_witch_index = 6;
                    33: get_witch_index = 7;
                    34: get_witch_index = 8;
                    35: get_witch_index = 9;
                    36: get_witch_index = 10;
                    37: get_witch_index = 11;
                    38: get_witch_index = 12;
                    39: get_witch_index = 13;
                    40: get_witch_index = 14;
                    41: get_witch_index = 15;
                    42: get_witch_index = 4;
                    43: get_witch_index = 5;
                    44: get_witch_index = 6;
                    45: get_witch_index = 7;
                    46: get_witch_index = 8;
                    47: get_witch_index = 9;
                    48: get_witch_index = 10;
                    49: get_witch_index = 11;
                    50: get_witch_index = 12;
                    51: get_witch_index = 13;
                    52: get_witch_index = 14;
                    53: get_witch_index = 15;
                    54: get_witch_index = 5;
                    55: get_witch_index = 6;
                    56: get_witch_index = 7;
                    57: get_witch_index = 8;
                    58: get_witch_index = 9;
                    59: get_witch_index = 10;
                    60: get_witch_index = 11;
                    61: get_witch_index = 12;
                    62: get_witch_index = 13;
                    63: get_witch_index = 14;
                    64: get_witch_index = 15;
                    65: get_witch_index = 6;
                    66: get_witch_index = 7;
                    67: get_witch_index = 8;
                    68: get_witch_index = 9;
                    69: get_witch_index = 10;
                    70: get_witch_index = 11;
                    71: get_witch_index = 12;
                    72: get_witch_index = 13;
                    73: get_witch_index = 14;
                    74: get_witch_index = 15;
                    75: get_witch_index = 7;
                    76: get_witch_index = 8;
                    77: get_witch_index = 9;
                    78: get_witch_index = 10;
                    79: get_witch_index = 11;
                    80: get_witch_index = 12;
                    81: get_witch_index = 13;
                    82: get_witch_index = 14;
                    83: get_witch_index = 15;
                    84: get_witch_index = 8;
                    85: get_witch_index = 9;
                    86: get_witch_index = 10;
                    87: get_witch_index = 11;
                    88: get_witch_index = 12;
                    89: get_witch_index = 13;
                    90: get_witch_index = 14;
                    91: get_witch_index = 15;
                    92: get_witch_index = 9;
                    93: get_witch_index = 10;
                    94: get_witch_index = 11;
                    95: get_witch_index = 12;
                    96: get_witch_index = 13;
                    97: get_witch_index = 14;
                    98: get_witch_index = 15;
                    99: get_witch_index = 10;
                    100: get_witch_index = 11;
                    101: get_witch_index = 12;
                    102: get_witch_index = 13;
                    103: get_witch_index = 14;
                    104: get_witch_index = 15;
                    105: get_witch_index = 11;
                    106: get_witch_index = 12;
                    107: get_witch_index = 13;
                    108: get_witch_index = 14;
                    109: get_witch_index = 15;
                    110: get_witch_index = 12;
                    111: get_witch_index = 13;
                    112: get_witch_index = 14;
                    113: get_witch_index = 15;
                    114: get_witch_index = 13;
                    115: get_witch_index = 14;
                    116: get_witch_index = 15;
                    117: get_witch_index = 14;
                    118: get_witch_index = 15;
                    119: get_witch_index = 15;
                    120: get_witch_index = 15;
                    121: get_witch_index = 15;
                    122: get_witch_index = 15;
                    123: get_witch_index = 15;
                    124: get_witch_index = 15;
                    125: get_witch_index = 15;
                    126: get_witch_index = 15;
                    127: get_witch_index = 15;
                    128: get_witch_index = 15;
                    129: get_witch_index = 15;
                    130: get_witch_index = 15;
                    131: get_witch_index = 15;
                    132: get_witch_index = 15;
                    133: get_witch_index = 15;
                    134: get_witch_index = 15;
                    135: get_witch_index = 15;
                endcase
            end
        end
    endfunction
    
    // Helper function to get witch data by index
    task get_witch_data;
        input [7:0] idx;
        output [15:0] x_val;
        output [15:0] y_val;
        output [15:0] r_val;
        begin
            case (idx)
                0: begin x_val = x_0; y_val = y_0; r_val = r_0; end
                1: begin x_val = x_1; y_val = y_1; r_val = r_1; end
                2: begin x_val = x_2; y_val = y_2; r_val = r_2; end
                3: begin x_val = x_3; y_val = y_3; r_val = r_3; end
                4: begin x_val = x_4; y_val = y_4; r_val = r_4; end
                5: begin x_val = x_5; y_val = y_5; r_val = r_5; end
                6: begin x_val = x_6; y_val = y_6; r_val = r_6; end
                7: begin x_val = x_7; y_val = y_7; r_val = r_7; end
                8: begin x_val = x_8; y_val = y_8; r_val = r_8; end
                9: begin x_val = x_9; y_val = y_9; r_val = r_9; end
                10: begin x_val = x_10; y_val = y_10; r_val = r_10; end
                11: begin x_val = x_11; y_val = y_11; r_val = r_11; end
                12: begin x_val = x_12; y_val = y_12; r_val = r_12; end
                13: begin x_val = x_13; y_val = y_13; r_val = r_13; end
                14: begin x_val = x_14; y_val = y_14; r_val = r_14; end
                15: begin x_val = x_15; y_val = y_15; r_val = r_15; end
                default: begin x_val = 16'd0; y_val = 16'd0; r_val = 16'd0; end
            endcase
        end
    endtask
    
    // Initialize LUTs (simple sine/cosine approximation)
    integer lut_idx;
    initial begin
        // Initialize with approximate values (actual values would be pre-computed)
        for (lut_idx = 0; lut_idx < 256; lut_idx = lut_idx + 1) begin
            // Simple approximation for testing
            cos_lut[lut_idx] = 16'h7FFF * $cos(2 * 3.14159 * lut_idx / 256.0);
            sin_lut[lut_idx] = 16'h7FFF * $sin(2 * 3.14159 * lut_idx / 256.0);
        end
    end
    
    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            busy <= 1'b0;
            done <= 1'b0;
            result <= RESULT_OK;
            cycle_count <= 8'd0;
            pair_counter <= 8'd0;
            collision_detected <= 1'b0;
            i_index <= 8'd0;
            j_index <= 8'd0;
            valid_pair <= 1'b0;
            // Initialize all endpoint arrays
            for (lut_idx = 0; lut_idx < 16; lut_idx = lut_idx + 1) begin
                endpoint_x[lut_idx] <= 32'd0;
                endpoint_y[lut_idx] <= 32'd0;
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    busy <= 1'b0;
                    result <= RESULT_OK;
                    cycle_count <= 8'd0;
                    pair_counter <= 8'd0;
                    collision_detected <= 1'b0;
                    i_index <= 8'd0;
                    j_index <= 8'd0;
                    valid_pair <= 1'b0;
                end
                
                FETCH: begin
                    // Fetch witch data for current pair
                    i_index <= get_witch_index(pair_counter, 0);
                    j_index <= get_witch_index(pair_counter, 1);
                    valid_pair <= 1'b0;
                    
                    // Check if both witches are active
                    if (valid_pair_check(i_index, j_index)) begin
                        valid_pair <= 1'b1;
                    end
                    cycle_count <= cycle_count + 8'd1;
                end
                
                COMPUTE: begin
                    if (valid_pair) begin
                        // Calculate endpoints using LUT
                        // Get witch data
                        get_witch_data(i_index, x_curr, y_curr, r_curr_temp);
                        get_witch_data(j_index, x_other, y_other, r_other_temp);
                        
                        // Compute endpoint for i: (x + cos(r), y + sin(r))
                        // r is 16-bit, use upper 8 bits for LUT index
                        // Cosine: endpoint_x = x_i + (cos_lut[r_i[15:8]] * length)
                        // Sine: endpoint_y = y_i + (sin_lut[r_i[15:8]] * length)
                        
                        // For i
                        endpoint_x[i_index] <= {8'd0, x_curr} + (({16'd0, cos_lut[r_curr_temp[15:8]]} * 16'd1024) >> 16);
                        endpoint_y[i_index] <= {8'd0, y_curr} + (({16'd0, sin_lut[r_curr_temp[15:8]]} * 16'd1024) >> 16);
                        
                        // For j
                        endpoint_x[j_index] <= {8'd0, x_other} + (({16'd0, cos_lut[r_other_temp[15:8]]} * 16'd1024) >> 16);
                        endpoint_y[j_index] <= {8'd0, y_other} + (({16'd0, sin_lut[r_other_temp[15:8]]} * 16'd1024) >> 16);
                    end
                end
                
                CHECK: begin
                    if (valid_pair) begin
                        // Calculate squared distance between endpoints
                        // dx = (endpoint_x[i] - endpoint_x[j])^2
                        diff_temp_x <= (endpoint_x[i_index] > endpoint_x[j_index]) ? 
                                       (endpoint_x[i_index] - endpoint_x[j_index]) : 
                                       (endpoint_x[j_index] - endpoint_x[i_index]);
                        diff_temp_y <= (endpoint_y[i_index] > endpoint_y[j_index]) ? 
                                       (endpoint_y[i_index] - endpoint_y[j_index]) : 
                                       (endpoint_y[j_index] - endpoint_y[i_index]);
                        
                        // Multiply for squared distance (32-bit result)
                        mult_temp_a <= diff_temp_x * diff_temp_x;
                        mult_temp_b <= diff_temp_y * diff_temp_y;
                    end
                    
                    // Move to next pair
                    pair_counter <= pair_counter + 8'd1;
                end
                
                FINISH: begin
                    done <= 1'b1;
                    if (collision_detected) begin
                        result <= RESULT_CRASH;
                    end else if (cycle_count >= MAX_CYCLES) begin
                        result <= RESULT_TIMEOUT;
                    end else begin
                        result <= RESULT_OK;
                    end
                    busy <= 1'b0;
                end
                
                ERROR: begin
                    done <= 1'b1;
                    result <= RESULT_ERROR;
                    busy <= 1'b0;
                end
                
                default: begin
                    state <= IDLE;
                    busy <= 1'b0;
                    done <= 1'b0;
                    result <= RESULT_ERROR;
                end
            endcase
            
            // Check collision condition in CHECK state
            if (state == CHECK && valid_pair) begin
                dist_sq <= mult_temp_a + mult_temp_b;
                if ((mult_temp_a + mult_temp_b) < SQUARED_DIST_THRESHOLD) begin
                    collision_detected <= 1'b1;
                end
            end
        end
    end
    
    // State transition logic
    always @(*) begin
        next_state = IDLE;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = FETCH;
                end
            end
            
            FETCH: begin
                if (cycle_count > MAX_CYCLES) begin
                    next_state = FINISH;
                end else if (pair_counter < WITCHES_SQ) begin
                    next_state = COMPUTE;
                end else begin
                    next_state = FINISH;
                end
            end
            
            COMPUTE: begin
                next_state = CHECK;
            end
            
            CHECK: begin
                if (collision_detected) begin
                    next_state = FINISH;
                end else begin
                    next_state = FETCH;
                end
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            ERROR: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end
    
    // Helper function for valid pair check
    function valid_pair_check;
        input [7:0] idx1;
        input [7:0] idx2;
        begin
            // Check if both bits are set in valid_i mask
            if ((valid_i[idx1] && valid_i[idx2]) && (idx1 != idx2)) begin
                valid_pair_check = 1'b1;
            end else begin
                valid_pair_check = 1'b0;
            end
        end
    endfunction
    
    // Internal signals for temporary storage
    reg [15:0] x_curr_temp;
    reg [15:0] y_curr_temp;
    reg [15:0] r_curr_temp;
    reg [15:0] x_other_temp;
    reg [15:0] y_other_temp;
    reg [15:0] r_other_temp;
    
endmodule