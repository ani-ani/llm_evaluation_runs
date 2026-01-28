module rating_equalizer (
    input clk,
    input rst_n,
    input start,
    input [7:0] rating [0:9],
    input [3:0] n,
    output reg [7:0] result,
    output reg [15:0] match_count,
    output reg [9:0] match_out,
    output reg match_valid,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] CHECK_EQUAL = 3'd2;
    localparam [2:0] FIND_MAX = 3'd3;
    localparam [2:0] OUTPUT_MATCH = 3'd4;
    localparam [2:0] FINISH = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [7:0] ratings [0:9];
    reg [7:0] max_val;
    reg [7:0] second_max_val;
    reg [3:0] max_count;
    reg [3:0] max_idx;
    reg [3:0] second_max_idx;
    reg [3:0] i;
    reg [3:0] j;
    reg [3:0] process_idx;
    reg [15:0] cycle_counter;
    reg [9:0] temp_match_out;
    reg equal_flag;
    reg found_second_max;

    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            match_count <= 16'd0;
            match_out <= 10'd0;
            match_valid <= 1'b0;
            done <= 1'b0;
            // Initialize all ratings
            for (i = 0; i < 10; i = i + 1) begin
                ratings[i] <= 8'd0;
            end
            max_val <= 8'd0;
            second_max_val <= 8'd0;
            max_count <= 4'd0;
            max_idx <= 4'd0;
            second_max_idx <= 4'd0;
            i <= 4'd0;
            j <= 4'd0;
            process_idx <= 4'd0;
            cycle_counter <= 16'd0;
            temp_match_out <= 10'd0;
            equal_flag <= 1'b0;
            found_second_max <= 1'b0;
        end else begin
            state <= next_state;
            
            // Default outputs
            match_valid <= 1'b0;
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        // Load initial ratings
                        process_idx <= 4'd0;
                    end
                    // Reset counters
                    match_count <= 16'd0;
                    cycle_counter <= 16'd0;
                    equal_flag <= 1'b0;
                end

                LOAD: begin
                    // Load ratings one by one
                    if (process_idx < 10 && process_idx < n) begin
                        ratings[process_idx] <= rating[process_idx];
                        process_idx <= process_idx + 4'd1;
                    end
                end

                CHECK_EQUAL: begin
                    // Check if all valid ratings are equal
                    equal_flag <= 1'b1;
                    if (n > 4'd1) begin
                        if (ratings[0] != ratings[1]) begin
                            equal_flag <= 1'b0;
                        end
                    end
                    j <= 4'd2;
                end

                FIND_MAX: begin
                    // Sequential search for max and second max
                    if (i < n) begin
                        if (i == 4'd0) begin
                            max_val <= ratings[0];
                            max_idx <= 4'd0;
                            max_count <= 4'd1;
                            second_max_val <= 8'd0;
                            second_max_idx <= 4'd0;
                            found_second_max <= 1'b0;
                        end else begin
                            if (ratings[i] > max_val) begin
                                // New max found, old max becomes second max
                                second_max_val <= max_val;
                                second_max_idx <= max_idx;
                                found_second_max <= 1'b1;
                                // Update new max
                                max_val <= ratings[i];
                                max_idx <= i;
                                max_count <= 4'd1;
                            end else if (ratings[i] == max_val) begin
                                max_count <= max_count + 4'd1;
                            end else if (ratings[i] > second_max_val) begin
                                second_max_val <= ratings[i];
                                second_max_idx <= i;
                                found_second_max <= 1'b1;
                            end
                        end
                        i <= i + 4'd1;
                    end
                end

                OUTPUT_MATCH: begin
                    // Generate match output based on logic
                    temp_match_out <= 10'd0;
                    
                    if (max_count == 4'd3 && max_val > 8'd0) begin
                        // Decrement all 3 with max_val
                        // Find indices with max_val
                        j <= 4'd0;
                        process_idx <= 4'd0;
                        // We need to identify which indices to decrement
                        // Reset temp_match_out and set bits for max_val elements
                        // This will be done in the next cycle or combinatorial logic
                        // For simplicity, we'll set match_out directly based on current state
                        // But we need to know which indices have max_val
                        // Let's do it combinatorially in the state transition
                    end else begin
                        // Decrement top 2
                        if (max_val > 8'd0) begin
                            temp_match_out[max_idx] <= 1'b1;
                            if (found_second_max && second_max_val > 8'd0) begin
                                temp_match_out[second_max_idx] <= 1'b1;
                            end
                        end
                    end
                    
                    match_count <= match_count + 16'd1;
                    match_valid <= 1'b1;
                    
                    // Perform decrements
                    if (max_count == 4'd3 && max_val > 8'd0) begin
                        // Decrement all 3 max entries
                        for (i = 0; i < 10; i = i + 1) begin
                            if (i < n && ratings[i] == max_val && ratings[i] > 8'd0) begin
                                ratings[i] <= ratings[i] - 8'd1;
                            end
                        end
                    end else begin
                        if (max_val > 8'd0) begin
                            ratings[max_idx] <= max_val - 8'd1;
                            if (found_second_max && second_max_val > 8'd0) begin
                                ratings[second_max_idx] <= second_max_val - 8'd1;
                            end
                        end
                    end
                end

                FINISH: begin
                    // All equal, output result and done
                    result <= ratings[0];
                    done <= 1'b1;
                end
            endcase
            
            // Cycle counter increment
            if (state == OUTPUT_MATCH || state == CHECK_EQUAL || state == FIND_MAX) begin
                cycle_counter <= cycle_counter + 16'd1;
            end
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = LOAD;
            end

            LOAD: begin
                if (process_idx >= 10 || process_idx >= n) next_state = CHECK_EQUAL;
            end

            CHECK_EQUAL: begin
                // Need to check all elements
                if (j < n) begin
                    if (ratings[j] != ratings[0]) begin
                        equal_flag = 1'b0;
                    end
                    j = j + 4'd1;
                end else begin
                    if (equal_flag || n == 1) begin
                        next_state = FINISH;
                    end else begin
                        next_state = FIND_MAX;
                        i = 4'd0; // Reset i for FIND_MAX
                    end
                end
            end

            FIND_MAX: begin
                if (i >= n) begin
                    next_state = OUTPUT_MATCH;
                    i = 4'd0; // Reset i for OUTPUT_MATCH
                end else begin
                    next_state = FIND_MAX;
                end
            end

            OUTPUT_MATCH: begin
                next_state = CHECK_EQUAL;
                // Reset equal_flag for next check
                // equal_flag = 1'b0; // Not needed, will be set in CHECK_EQUAL
                // Need to reset i and j for CHECK_EQUAL loop
                i = 4'd0;
                j = 4'd1; // Start check from index 1
                equal_flag = 1'b1; // Assume equal until proven otherwise
            end

            FINISH: begin
                next_state = IDLE; // Self-loop to IDLE or wait for reset
                // Option: Stay in FINISH state until reset
                // next_state = FINISH; 
            end

            default: next_state = IDLE;
        endcase
    end

    // Generate match_out for OUTPUT_MATCH state (combinatorial)
    always @(*) begin
        match_out = 10'd0;
        if (state == OUTPUT_MATCH) begin
            if (max_count == 4'd3 && max_val > 8'd0) begin
                // Set bits for indices with max_val
                for (k = 0; k < 10; k = k + 1) begin
                    if (k < n && ratings[k] == max_val && ratings[k] > 8'd0) begin
                        match_out[k] = 1'b1;
                    end
                end
            end else begin
                if (max_val > 8'd0) begin
                    match_out[max_idx] = 1'b1;
                    if (found_second_max && second_max_val > 8'd0) begin
                        match_out[second_max_idx] = 1'b1;
                    end
                end
            end
        end
    end

    // Helper variable for match_out generation
    integer k;

endmodule