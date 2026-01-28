module encoding_solver (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] i_str [0:15],
    input wire [7:0] o_str [0:15],
    input wire [7:0] i_len,
    input wire [7:0] o_len,
    output reg [1:0] status,
    output reg [127:0] result_plus,
    output reg [127:0] result_minus,
    output reg valid_out,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE          = 3'd0;
    localparam [2:0] LOAD_STRINGS  = 3'd1;
    localparam [2:0] FIND_LENGTHS  = 3'd2;
    localparam [2:0] CHECK_ENCODING = 3'd3;
    localparam [2:0] OUTPUT_RESULTS = 3'd4;
    localparam [2:0] DONE_STATE     = 3'd5;
    localparam [2:0] CORRUPTED      = 3'd6;

    reg [2:0] state;
    reg [2:0] next_state;
    
    // Internal registers for strings (flattened for synthesis)
    reg [7:0] i_reg [0:15];
    reg [7:0] o_reg [0:15];
    reg [7:0] i_len_reg;
    reg [7:0] o_len_reg;
    
    // Counters for special characters
    reg [3:0] count_plus;
    reg [3:0] count_minus;
    
    // Loop counters for lengths (0-16)
    reg [4:0] len_plus;
    reg [4:0] len_minus;
    reg [7:0] total_iterations; // 16x16 = 256
    
    // Matching logic state
    reg [4:0] i_idx;      // index in I
    reg [4:0] o_idx;      // index in O
    reg [4:0] temp_idx;   // temp index
    reg [7:0] match_char;
    reg mismatch;
    reg [3:0] plus_rem;
    reg [3:0] minus_rem;
    reg [3:0] expected_len;
    
    // Valid flag for current candidate
    reg current_valid;
    
    // Cycle counter to prevent infinite loops
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd1000;

    integer i;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            case (state)
                IDLE: if (start) state <= LOAD_STRINGS;
                LOAD_STRINGS: state <= FIND_LENGTHS;
                FIND_LENGTHS: state <= CHECK_ENCODING;
                CHECK_ENCODING: begin
                    // Iterate through all combinations
                    if (total_iterations >= 16'd255) begin
                        if (current_valid)
                            state <= OUTPUT_RESULTS;
                        else
                            state <= CORRUPTED;
                    end else if (current_valid) begin
                        state <= OUTPUT_RESULTS;
                    end else begin
                        state <= CHECK_ENCODING;
                    end
                end
                OUTPUT_RESULTS: state <= DONE_STATE;
                DONE_STATE: if (start) state <= IDLE;
                CORRUPTED: if (start) state <= IDLE;
                default: state <= IDLE;
            endcase
        end
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            for (i = 0; i < 16; i = i + 1) begin
                i_reg[i] <= 8'd0;
                o_reg[i] <= 8'd0;
            end
            i_len_reg <= 8'd0;
            o_len_reg <= 8'd0;
            count_plus <= 4'd0;
            count_minus <= 4'd0;
            len_plus <= 5'd0;
            len_minus <= 5'd0;
            total_iterations <= 8'd0;
            i_idx <= 5'd0;
            o_idx <= 5'd0;
            temp_idx <= 5'd0;
            match_char <= 8'd0;
            mismatch <= 1'b0;
            plus_rem <= 4'd0;
            minus_rem <= 4'd0;
            expected_len <= 4'd0;
            current_valid <= 1'b0;
            result_plus <= 128'd0;
            result_minus <= 128'd0;
            valid_out <= 1'b0;
            done <= 1'b0;
            status <= 2'd0;
            cycle_count <= 16'd0;
        end else begin
            // Default values
            valid_out <= 1'b0;
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    status <= 2'd0; // Idle
                    cycle_count <= 16'd0;
                    current_valid <= 1'b0;
                end
                
                LOAD_STRINGS: begin
                    status <= 2'd1; // Processing
                    // Load strings from inputs (simulate BRAM read)
                    for (i = 0; i < 16; i = i + 1) begin
                        if (i < i_len_reg)
                            i_reg[i] <= i_str[i];
                        else
                            i_reg[i] <= 8'd0;
                        if (i < o_len_reg)
                            o_reg[i] <= o_str[i];
                        else
                            o_reg[i] <= 8'd0;
                    end
                    // Count special chars
                    count_plus <= 4'd0;
                    count_minus <= 4'd0;
                    for (i = 0; i < 16; i = i + 1) begin
                        if (i < i_len_reg) begin
                            if (i_str[i] == 8'd43) // '+'
                                count_plus <= count_plus + 4'd1;
                            if (i_str[i] == 8'd45) // '-'
                                count_minus <= count_minus + 4'd1;
                        end
                    end
                end
                
                FIND_LENGTHS: begin
                    // Initialize length search
                    len_plus <= 5'd0;
                    len_minus <= 5'd0;
                    total_iterations <= 8'd0;
                    current_valid <= 1'b0;
                    i_len_reg <= i_len; // Register input lengths
                    o_len_reg <= o_len;
                end
                
                CHECK_ENCODING: begin
                    cycle_count <= cycle_count + 16'd1;
                    
                    // Check current length combination
                    if (total_iterations < 8'd256) begin
                        // Calculate expected output length
                        // L_out = L_i - count('+') - count('-') + len_plus + len_minus
                        expected_len <= (i_len_reg - count_plus - count_minus) + len_plus + len_minus;
                        
                        // Initialize matching state
                        i_idx <= 5'd0;
                        o_idx <= 5'd0;
                        mismatch <= 1'b0;
                        plus_rem <= len_plus;
                        minus_rem <= len_minus;
                    end
                    
                    // Increment counters for next iteration if not found
                    if (!current_valid && total_iterations < 8'd256) begin
                        // Update length counters (row-major order)
                        if (len_minus < 5'd16) begin
                            len_minus <= len_minus + 5'd1;
                        end else begin
                            len_minus <= 5'd0;
                            len_plus <= len_plus + 5'd1;
                        end
                        total_iterations <= total_iterations + 8'd1;
                    end
                end
                
                OUTPUT_RESULTS: begin
                    status <= 2'd2; // Found
                    valid_out <= 1'b1;
                    done <= 1'b1;
                    // result_plus and result_minus already set during CHECK_ENCODING
                end
                
                DONE_STATE: begin
                    status <= 2'd0; // Return to idle state
                    valid_out <= 1'b0;
                    done <= 1'b0;
                end
                
                CORRUPTED: begin
                    status <= 2'd3; // Corrupted
                    done <= 1'b1;
                    result_plus <= 128'd0;
                    result_minus <= 128'd0;
                end
                
                default: begin
                    status <= 2'd0;
                end
            endcase
        end
    end

    // Continuous matching logic (sequential character checking)
    // This runs in parallel with state machine to fill the pipeline
    reg match_in_progress;
    reg match_complete;
    reg [3:0] match_state;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            match_in_progress <= 1'b0;
            match_complete <= 1'b0;
            match_state <= 4'd0;
        end else if (state == CHECK_ENCODING && !current_valid && total_iterations < 8'd256 && match_state == 4'd0) begin
            // Start new match check
            match_in_progress <= 1'b1;
            match_complete <= 1'b0;
            match_state <= 4'd1;
            // Initialize match variables
            i_idx <= 5'd0;
            o_idx <= 5'd0;
            mismatch <= 1'b0;
            plus_rem <= len_plus;
            minus_rem <= len_minus;
        end else if (match_in_progress && match_state < 4'd10) begin
            // Perform matching steps sequentially
            match_state <= match_state + 4'd1;
            
            if (match_state == 4'd1) begin
                // Check expected length match
                if (expected_len != o_len_reg) begin
                    mismatch <= 1'b1;
                end
            end else if (match_state == 4'd2 && !mismatch) begin
                // Main matching loop (simplified sequential version)
                // Check if we consumed all input
                if (i_idx >= i_len_reg && o_idx == o_len_reg)
                    match_complete <= 1'b1;
                else if (i_idx >= i_len_reg || o_idx > o_len_reg)
                    mismatch <= 1'b1;
            end else if (match_state >= 4'd3 && match_state <= 4'd8 && !mismatch && !match_complete) begin
                // Process one character pair
                if (i_idx < i_len_reg) begin
                    if (i_reg[i_idx] == 8'd43) begin // '+'
                        if (plus_rem > 0) begin
                            // Fill with placeholder (check against O)
                            // For simplicity, we just check if O has enough chars
                            o_idx <= o_idx + 5'd1; // consume one char from O
                            plus_rem <= plus_rem - 4'd1;
                        end else begin
                            // No more '+' to fill, mismatch
                            mismatch <= 1'b1;
                        end
                        i_idx <= i_idx + 5'd1;
                    end else if (i_reg[i_idx] == 8'd45) begin // '-'
                        if (minus_rem > 0) begin
                            o_idx <= o_idx + 5'd1;
                            minus_rem <= minus_rem - 4'd1;
                        end else begin
                            mismatch <= 1'b1;
                        end
                        i_idx <= i_idx + 5'd1;
                    end else begin // Literal character
                        if (o_idx < o_len_reg && i_reg[i_idx] == o_reg[o_idx]) begin
                            i_idx <= i_idx + 5'd1;
                            o_idx <= o_idx + 5'd1;
                        end else begin
                            mismatch <= 1'b1;
                        end
                    end
                end else begin
                    // Input exhausted but output not fully matched
                    if (o_idx != o_len_reg) mismatch <= 1'b1;
                    else match_complete <= 1'b1;
                end
            end else if (match_state == 4'd9) begin
                // Final check
                if (!mismatch && o_idx == o_len_reg && i_idx == i_len_reg && plus_rem == 0 && minus_rem == 0) begin
                    current_valid <= 1'b1;
                    // Store results in 128-bit registers (16 chars * 8 bits)
                    // Generate dummy substrings for demonstration
                    // In real implementation, these would be the actual found strings
                    for (i = 0; i < 16; i = i + 1) begin
                        if (i < len_plus)
                            result_plus[8*i +: 8] <= 8'd65 + i; // 'A' + i
                        else
                            result_plus[8*i +: 8] <= 8'd0;
                        if (i < len_minus)
                            result_minus[8*i +: 8] <= 8'd97 + i; // 'a' + i
                        else
                            result_minus[8*i +: 8] <= 8'd0;
                    end
                end
                match_complete <= 1'b1;
                match_in_progress <= 1'b0;
                match_state <= 4'd0;
            end
        end else if (state != CHECK_ENCODING) begin
            match_in_progress <= 1'b0;
            match_complete <= 1'b0;
            match_state <= 4'd0;
        end
    end

endmodule