module pattern_probability_sorter(
    input clk,
    input rst_n,
    input start,
    input [2:0] num_patterns,
    input [7:0] pattern_length,
    input [63:0] predictions_0,
    input [63:0] predictions_1,
    input [63:0] predictions_2,
    input [63:0] predictions_3,
    input [63:0] predictions_4,
    input [63:0] predictions_5,
    input [63:0] predictions_6,
    input [63:0] predictions_7,
    output reg [2:0] sorted_indices [0:7],
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam PARSE = 3'b001;
    localparam COMPUTE_SCORES = 3'b010;
    localparam SORT = 3'b011;
    localparam DONE = 3'b100;

    // Constants
    localparam N = 64; // Max rounds
    localparam MAX_PATTERNS = 8;
    localparam MAX_LEN = 8;

    // Registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [2:0] pattern_idx;
    reg [2:0] sort_idx;
    reg [2:0] swap_idx;
    
    // Pattern storage (8 patterns, 8 bytes each)
    reg [7:0] patterns [0:7][0:7];
    reg [2:0] indices [0:7];
    reg [63:0] scores [0:7]; // Q16.16
    
    // Intermediate calculation registers
    reg [63:0] current_pattern_data;
    reg [31:0] reciprocal_val;
    reg [31:0] score_calc;
    reg [31:0] overlap_penalty;
    reg [31:0] overlap_factor;
    
    // Control flags
    reg parsing_done;
    reg scores_done;
    reg sorting_done;
    reg swap_needed;

    // Helper signals for pattern extraction
    wire [7:0] byte_0, byte_1, byte_2, byte_3, byte_4, byte_5, byte_6, byte_7;
    
    // Extract bytes from current pattern data
    assign byte_7 = current_pattern_data[63:56];
    assign byte_6 = current_pattern_data[55:48];
    assign byte_5 = current_pattern_data[47:40];
    assign byte_4 = current_pattern_data[39:32];
    assign byte_3 = current_pattern_data[31:24];
    assign byte_2 = current_pattern_data[23:16];
    assign byte_1 = current_pattern_data[15:8];
    assign byte_0 = current_pattern_data[7:0];

    // Reciprocal lookup for 3^L (Q16.16 format)
    // 3^1=3, reciprocal=21845 (0x5555)
    // 3^2=9, reciprocal=7281 (0x1C71)
    // 3^3=27, reciprocal=2430 (0x0978)
    // 3^4=81, reciprocal=810 (0x02CA)
    // 3^5=243, reciprocal=270 (0x010E)
    // 3^6=729, reciprocal=90 (0x005A)
    // 3^7=2187, reciprocal=30 (0x001E)
    // 3^8=6561, reciprocal=10 (0x000A)
    always @(*) begin
        case(pattern_length)
            8'd1: reciprocal_val = 32'd21845;
            8'd2: reciprocal_val = 32'd7281;
            8'd3: reciprocal_val = 32'd2430;
            8'd4: reciprocal_val = 32'd810;
            8'd5: reciprocal_val = 32'd270;
            8'd6: reciprocal_val = 32'd90;
            8'd7: reciprocal_val = 32'd30;
            8'd8: reciprocal_val = 32'd10;
            default: reciprocal_val = 32'd0;
        endcase
    end

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = PARSE;
                else next_state = IDLE;
            end
            PARSE: begin
                if (parsing_done) next_state = COMPUTE_SCORES;
                else next_state = PARSE;
            end
            COMPUTE_SCORES: begin
                if (scores_done) next_state = SORT;
                else next_state = COMPUTE_SCORES;
            end
            SORT: begin
                if (sorting_done) next_state = DONE;
                else next_state = SORT;
            end
            DONE: next_state = DONE;
            default: next_state = IDLE;
        endcase
    end

    // Control signals and datapath
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pattern_idx <= 0;
            parsing_done <= 0;
            scores_done <= 0;
            sorting_done <= 0;
            done <= 0;
            sort_idx <= 0;
            swap_idx <= 0;
            // Reset indices
            for (integer i = 0; i < 8; i = i + 1) begin
                indices[i] <= i;
                scores[i] <= 0;
                sorted_indices[i] <= 0;
            end
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        pattern_idx <= 0;
                        parsing_done <= 0;
                        scores_done <= 0;
                        sorting_done <= 0;
                        done <= 0;
                    end
                end

                PARSE: begin
                    if (pattern_idx < num_patterns) begin
                        // Select correct input based on pattern_idx
                        case (pattern_idx)
                            3'd0: current_pattern_data <= predictions_0;
                            3'd1: current_pattern_data <= predictions_1;
                            3'd2: current_pattern_data <= predictions_2;
                            3'd3: current_pattern_data <= predictions_3;
                            3'd4: current_pattern_data <= predictions_4;
                            3'd5: current_pattern_data <= predictions_5;
                            3'd6: current_pattern_data <= predictions_6;
                            3'd7: current_pattern_data <= predictions_7;
                        endcase
                        
                        // Store extracted bytes (implicitly done via always block below)
                        pattern_idx <= pattern_idx + 1;
                    end else begin
                        parsing_done <= 1;
                    end
                    
                    // Extract and store bytes
                    patterns[pattern_idx][0] <= byte_0;
                    patterns[pattern_idx][1] <= byte_1;
                    patterns[pattern_idx][2] <= byte_2;
                    patterns[pattern_idx][3] <= byte_3;
                    patterns[pattern_idx][4] <= byte_4;
                    patterns[pattern_idx][5] <= byte_5;
                    patterns[pattern_idx][6] <= byte_6;
                    patterns[pattern_idx][7] <= byte_7;
                end

                COMPUTE_SCORES: begin
                    if (pattern_idx < num_patterns) begin
                        // Calculate overlap penalty
                        // Simple check: count how many prefix-suffix matches exist
                        // For this implementation, we check specific overlap patterns
                        overlap_penalty <= 0;
                        
                        // Check overlaps for current pattern
                        // L=3+: check last 2 chars vs first 2, etc.
                        if (pattern_length >= 3) begin
                            if (patterns[pattern_idx][pattern_length-1] == patterns[pattern_idx][0] && 
                                patterns[pattern_idx][pattern_length-2] == patterns[pattern_idx][1]) begin
                                overlap_penalty <= 1;
                            end
                        end
                        if (pattern_length >= 5) begin
                            if (patterns[pattern_idx][pattern_length-1] == patterns[pattern_idx][0] && 
                                patterns[pattern_idx][pattern_length-2] == patterns[pattern_idx][1] &&
                                patterns[pattern_idx][pattern_length-3] == patterns[pattern_idx][2]) begin
                                overlap_penalty <= overlap_penalty + 1;
                            end
                        end
                        
                        // Calculate score: (N - L + 1) * reciprocal
                        // (N - L + 1) max is 64, fits in 8 bits
                        // Multiply: 32-bit result, upper 16 bits are integer, lower 16 are fractional
                        // We take the integer part as score
                        score_calc <= (N - pattern_length + 8'h1) * reciprocal_val;
                        
                        // Apply penalty: effective_count = count * (1 - penalty_factor)
                        // penalty_factor is roughly 0.25 for overlap=1 (approximation)
                        // Using integer math: score = score - (score >> 2) * overlap_penalty
                        if (overlap_penalty > 0) begin
                            scores[pattern_idx] <= (score_calc >> 16) - ((score_calc >> 18) * overlap_penalty);
                        end else begin
                            scores[pattern_idx] <= (score_calc >> 16);
                        end
                        
                        pattern_idx <= pattern_idx + 1;
                        scores_done <= 0;
                    end else begin
                        scores_done <= 1;
                        pattern_idx <= 0;
                    end
                end

                SORT: begin
                    if (!sorting_done) begin
                        // Bubble sort iteration
                        if (swap_idx < num_patterns - 1 - sort_idx) begin
                            // Compare scores of adjacent elements
                            if (scores[indices[swap_idx]] < scores[indices[swap_idx + 1]]) begin
                                // Swap indices
                                indices[swap_idx] <= indices[swap_idx + 1];
                                indices[swap_idx + 1] <= indices[swap_idx];
                                swap_needed <= 1;
                            end else begin
                                swap_needed <= 0;
                            end
                            swap_idx <= swap_idx + 1;
                        end else begin
                            // End of pass
                            sort_idx <= sort_idx + 1;
                            swap_idx <= 0;
                            
                            // Check if sorting is complete
                            if (sort_idx == num_patterns - 2) begin
                                sorting_done <= 1;
                                // Copy to output
                                sorted_indices[0] <= indices[0];
                                sorted_indices[1] <= indices[1];
                                sorted_indices[2] <= indices[2];
                                sorted_indices[3] <= indices[3];
                                sorted_indices[4] <= indices[4];
                                sorted_indices[5] <= indices[5];
                                sorted_indices[6] <= indices[6];
                                sorted_indices[7] <= indices[7];
                            end
                        end
                    end
                end

                DONE: begin
                    done <= 1;
                end
            endcase
        end
    end

endmodule