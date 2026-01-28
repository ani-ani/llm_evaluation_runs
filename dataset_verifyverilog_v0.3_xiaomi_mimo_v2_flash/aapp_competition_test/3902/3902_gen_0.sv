module reberland_linguistics (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] char_in,
    input wire [4:0] str_len,
    output reg done,
    output reg [4:0] suffix_count,
    output reg [7:0] suffix_char,
    output reg [2:0] suffix_len,
    output reg [2:0] output_index
);

// Module computes valid suffixes for Reberland language parsing
// String length: 5-16 characters (scaled from 10^4)
// Suffixes: 2-3 characters, distinct, no consecutive duplicates
// Algorithm: Process backwards from end, use DP states

// Internal states
localparam [2:0] IDLE = 3'b000;
localparam [2:0] COMPUTE = 3'b001;
localparam [2:0] VALIDATE = 3'b010;
localparam [2:0] OUTPUT = 3'b011;
localparam [2:0] DONE = 3'b100;

reg [2:0] state;
reg [2:0] next_state;
reg [4:0] pos;  // Current position in string
reg [4:0] root_min; // Minimum root position (5)

// DP states: dp2[i] = 1 if valid suffix of length 2 starting at i
//            dp3[i] = 1 if valid suffix of length 3 starting at i  
reg [15:0] dp2;  // Bitmask for positions 0-15
reg [15:0] dp3;

// Storage for found suffixes (up to 8)
reg [23:0] suffix_storage [0:7]; // 3 chars × 8 bits = 24 bits per suffix
reg [2:0] stored_count;
reg [2:0] output_ptr;

// String buffer (16 chars × 8 bits)
reg [7:0] string_buf [0:15];

// Helper: compare two suffixes for equality
function equal_suffix;
    input [23:0] a;
    input [23:0] b;
    input [1:0] len; // 2 or 3
    begin
        if (len == 2) begin
            equal_suffix = (a[15:0] == b[15:0]);
        end else begin
            equal_suffix = (a == b);
        end
    end
endfunction

// Helper: lexicographical comparison
function less_than;
    input [23:0] a;
    input [23:0] b;
    input [1:0] len_a;
    input [1:0] len_b;
    reg [7:0] char_a, char_b;
    integer i;
    begin
        less_than = 0;
        for (i = 0; i < 3; i = i + 1) begin
            char_a = (i < len_a) ? a[8*i+:8] : 8'hFF;
            char_b = (i < len_b) ? b[8*i+:8] : 8'hFF;
            if (char_a < char_b) begin
                less_than = 1;
                return;
            end else if (char_a > char_b) begin
                return;
            end
        end
        // If all chars equal, shorter string comes first
        if (len_a < len_b) less_than = 1;
    end
endfunction

// State transition logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 0;
        suffix_count <= 0;
        suffix_char <= 0;
        suffix_len <= 0;
        output_index <= 0;
        pos <= 0;
        stored_count <= 0;
        output_ptr <= 0;
        dp2 <= 0;
        dp3 <= 0;
        root_min <= 0;
    end else begin
        state <= next_state;
        
        case (state)
            IDLE: begin
                done <= 0;
                if (start) begin
                    root_min <= 5;
                    pos <= str_len - 1;
                    dp2 <= 0;
                    dp3 <= 0;
                    stored_count <= 0;
                    output_ptr <= 0;
                    // Initialize end conditions
                    if (str_len >= 7) begin
                        dp2[str_len-2] <= 1;
                    end
                    if (str_len >= 8) begin
                        dp3[str_len-3] <= 1;
                    end
                end
            end
            
            COMPUTE: begin
                // Process backwards: check if valid suffix can start at pos
                if (pos >= 5 && pos < str_len) begin
                    // Check 2-char suffix
                    if (pos <= str_len - 2) begin
                        // Valid if: (no following 2-char duplicate AND next is valid) OR next 3-char valid
                        if (((dp2[pos+2] && 
                              string_buf[pos] != string_buf[pos+2] || 
                              string_buf[pos+1] != string_buf[pos+3]) ||
                             dp3[pos+2]) && 
                            (dp2[pos+2] || dp3[pos+2])) begin
                            dp2[pos] <= 1;
                        end
                    end
                    // Check 3-char suffix  
                    if (pos <= str_len - 3) begin
                        if (((dp3[pos+3] && 
                              (string_buf[pos] != string_buf[pos+3] || 
                               string_buf[pos+1] != string_buf[pos+4] || 
                               string_buf[pos+2] != string_buf[pos+5])) ||
                             dp2[pos+3]) && 
                            (dp2[pos+3] || dp3[pos+3])) begin
                            dp3[pos] <= 1;
                        end
                    end
                end
            end
            
            VALIDATE: begin
                // Collect valid suffixes
                if (dp2[pos] && stored_count < 8) begin
                    // Store 2-char suffix
                    suffix_storage[stored_count] <= {8'h00, string_buf[pos], string_buf[pos+1]};
                    stored_count <= stored_count + 1;
                end
                if (dp3[pos] && stored_count < 8) begin
                    // Store 3-char suffix  
                    suffix_storage[stored_count] <= {string_buf[pos], string_buf[pos+1], string_buf[pos+2]};
                    stored_count <= stored_count + 1;
                end
                pos <= pos - 1;
            end
            
            OUTPUT: begin
                // Bubble sort the stored suffixes (simple for small count)
                if (output_ptr < stored_count - 1) begin
                    // Compare and swap if needed
                    if (less_than(suffix_storage[output_ptr+1], 
                                 suffix_storage[output_ptr],
                                 (suffix_storage[output_ptr+1][23:16] == 8'h00) ? 2 : 3,
                                 (suffix_storage[output_ptr][23:16] == 8'h00) ? 2 : 3)) begin
                        // Swap
                        suffix_storage[output_ptr] <= suffix_storage[output_ptr+1];
                        suffix_storage[output_ptr+1] <= suffix_storage[output_ptr];
                    end
                    output_ptr <= output_ptr + 1;
                end else begin
                    output_ptr <= 0;
                    suffix_count <= stored_count;
                end
            end
            
            DONE: begin
                // Output sorted suffixes one by one
                if (output_ptr < stored_count) begin
                    suffix_char <= suffix_storage[output_ptr][15:8];
                    suffix_len <= (suffix_storage[output_ptr][23:16] == 8'h00) ? 3'd2 : 3'd3;
                    output_index <= output_ptr + 1;
                    output_ptr <= output_ptr + 1;
                end else begin
                    done <= 1;
                end
            end
            
            default: begin
                state <= IDLE;
            end
        endcase
    end
end

// Next state logic
always @(*) begin
    next_state = state;
    case (state)
        IDLE: begin
            if (start) begin
                next_state = COMPUTE;
            end
        end
        
        COMPUTE: begin
            if (pos >= 5 && pos < str_len) begin
                next_state = VALIDATE;
            end else begin
                next_state = OUTPUT;
            end
        end
        
        VALIDATE: begin
            next_state = COMPUTE;
        end
        
        OUTPUT: begin
            if (output_ptr >= stored_count - 1 && stored_count > 0) begin
                next_state = DONE;
            end
        end
        
        DONE: begin
            if (output_ptr >= stored_count) begin
                next_state = IDLE;
            end
        end
        
        default: next_state = IDLE;
    endcase
end

endmodule