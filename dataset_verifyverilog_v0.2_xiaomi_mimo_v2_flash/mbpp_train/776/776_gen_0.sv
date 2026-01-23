module count_vowels (
    input clk,
    input rst_n,
    input start,
    input [5:0] str_len,
    input [127:0] str_data,
    output reg [5:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam CHECK = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state, next_state;
    reg [5:0] count_reg, next_count;
    reg [5:0] idx, next_idx;
    reg [5:0] result_reg, next_result;

    // Intermediate wires for combinational logic
    wire is_vowel [15:0];
    wire is_non_vowel [15:0];
    wire left_is_vowel [15:0];
    wire right_is_vowel [15:0];
    wire is_first;
    wire is_last;
    wire should_count_current;

    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : gen_vowel_check
            // Extract character byte
            wire [7:0] char = str_data[i*8 +: 8];
            // Check if character is a vowel (a, e, i, o, u)
            assign is_vowel[i] = (char == 8'h61 || char == 8'h65 || char == 8'h69 || char == 8'h6F || char == 8'h75);
            assign is_non_vowel[i] = !is_vowel[i];
            
            // Check neighbors (handle boundaries internally for indexing safety, logical checks are outside)
            // Left neighbor (index - 1)
            wire [7:0] left_char = (i > 0) ? str_data[(i-1)*8 +: 8] : 8'h00;
            wire left_is_vowel_wire = (i > 0) && 
                                       (left_char == 8'h61 || left_char == 8'h65 || left_char == 8'h69 || left_char == 8'h6F || left_char == 8'h75);
            assign left_is_vowel[i] = left_is_vowel_wire;

            // Right neighbor (index + 1)
            wire [7:0] right_char = (i < 15) ? str_data[(i+1)*8 +: 8] : 8'h00;
            wire right_is_vowel_wire = (i < 15) && 
                                        (right_char == 8'h61 || right_char == 8'h65 || right_char == 8'h69 || right_char == 8'h6F || right_char == 8'h75);
            assign right_is_vowel[i] = right_is_vowel_wire;
        end
    endgenerate

    // Logic for current index based on state machine iteration
    assign is_first = (idx == 0);
    assign is_last = (idx == str_len - 1);

    // Determine if current character should be counted based on index and neighbors
    // Rule: Non-vowel AND (left neighbor is vowel OR right neighbor is vowel)
    // Exception handling via conditional logic
    
    reg current_valid;
    
    always @(*) begin
        current_valid = 1'b0;
        if (is_non_vowel[idx]) begin
            if (is_first) begin
                // First char: needs right neighbor to be vowel
                if (right_is_vowel[idx]) current_valid = 1'b1;
            end else if (is_last) begin
                // Last char: needs left neighbor to be vowel
                if (left_is_vowel[idx]) current_valid = 1'b1;
            end else begin
                // Middle chars: needs left OR right to be vowel
                if (left_is_vowel[idx] || right_is_vowel[idx]) current_valid = 1'b1;
            end
        end
    end

    // State Register and Datapath
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            count_reg <= 0;
            idx <= 0;
            result_reg <= 0;
            result <= 0;
            done <= 0;
        end else begin
            state <= next_state;
            count_reg <= next_count;
            idx <= next_idx;
            result_reg <= next_result;
            result <= next_result; // Output register
            
            // Done signal logic (synchronized)
            if (next_state == DONE) 
                done <= 1'b1;
            else 
                done <= 1'b0;
        end
    end

    // Next State Logic
    always @(*) begin
        // Defaults
        next_state = state;
        next_count = count_reg;
        next_idx = idx;
        next_result = result_reg;

        case (state)
            IDLE: begin
                next_count = 0;
                next_idx = 0;
                next_result = 0;
                if (start) begin
                    next_state = CHECK;
                    // If string length is 0, skip directly to DONE
                    if (str_len == 0) begin
                        next_state = DONE;
                    end
                end
            end

            CHECK: begin
                // Process current index
                if (current_valid) begin
                    next_count = count_reg + 1;
                end else begin
                    next_count = count_reg;
                end

                // Increment index
                next_idx = idx + 1;

                // Check if we reached the end of the string
                if (idx == str_len - 1) begin
                    next_state = DONE;
                    next_result = next_count; // Register result at end of cycle
                end else begin
                    next_state = CHECK;
                    next_result = result_reg; // Keep old result
                end
            end

            DONE: begin
                // Wait for reset or start
                if (start) begin
                    next_state = CHECK;
                    next_count = 0;
                    next_idx = 0;
                    next_result = 0;
                end else begin
                    next_state = DONE;
                end
            end

            default: next_state = IDLE;
        endcase
    end

endmodule
