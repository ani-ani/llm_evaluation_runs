module balanced_parentheses_solver (
    input clk,
    input rst_n,
    input start,
    input [5:0] num_pieces,
    input [7:0][15:0] pieces,
    output reg [9:0] max_length,
    output reg done
);

    // State definitions
    localparam IDLE = 3'd0;
    localparam PARSE_PIECES = 3'd1;
    localparam EVALUATE_SUBSETS = 3'd2;
    localparam DONE = 3'd3;

    // Piece properties storage
    reg signed [4:0] piece_min_prefix [0:7];   // Min balance (signed)
    reg signed [4:0] piece_final_balance [0:7]; // Net balance (signed)
    reg [4:0] piece_len [0:7];                 // Length

    // FSM state
    reg [2:0] state;
    
    // Parsing logic
    reg [3:0] parse_idx;
    reg [3:0] parse_char_idx;
    reg signed [4:0] p_bal, p_min;
    reg [4:0] p_len;

    // Subset evaluation
    reg [7:0] subset_idx;
    reg [2:0] piece_selector;
    reg signed [9:0] curr_bal;
    reg signed [9:0] curr_len;
    reg eval_valid;
    
    // Helper for subset limit
    wire [7:0] limit;
    assign limit = 8'h1 << num_pieces[2:0];

    // State Machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            max_length <= 0;
            parse_idx <= 0;
            parse_char_idx <= 0;
            subset_idx <= 0;
            piece_selector <= 0;
            p_bal <= 0;
            p_min <= 0;
            p_len <= 0;
            curr_bal <= 0;
            curr_len <= 0;
            eval_valid <= 1;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        parse_idx <= 0;
                        parse_char_idx <= 0;
                        p_bal <= 0;
                        p_min <= 0;
                        p_len <= 0;
                        state <= PARSE_PIECES;
                        done <= 0;
                    end
                end

                PARSE_PIECES: begin
                    if (parse_idx < num_pieces[2:0]) begin
                        if (parse_char_idx < 16) begin
                            // Process one character
                            case (pieces[parse_idx][parse_char_idx*2 +: 2])
                                2'b01: begin // (
                                    p_bal <= p_bal + 1;
                                    if (p_bal + 1 < p_min) p_min <= p_bal + 1;
                                    p_len <= p_len + 1;
                                end
                                2'b10: begin // )
                                    p_bal <= p_bal - 1;
                                    if (p_bal - 1 < p_min) p_min <= p_bal - 1;
                                    p_len <= p_len + 1;
                                end
                                default: begin // Padding
                                    // Do nothing
                                end
                            endcase
                            parse_char_idx <= parse_char_idx + 1;
                        end else begin
                            // Finished piece, store results
                            piece_len[parse_idx] <= p_len;
                            piece_min_prefix[parse_idx] <= p_min;
                            piece_final_balance[parse_idx] <= p_bal;
                            // Reset for next piece
                            p_bal <= 0;
                            p_min <= 0;
                            p_len <= 0;
                            parse_char_idx <= 0;
                            parse_idx <= parse_idx + 1;
                        end
                    end else begin
                        // All pieces parsed
                        subset_idx <= 1; // Start from subset 1 (skip empty)
                        piece_selector <= 0;
                        curr_bal <= 0;
                        curr_len <= 0;
                        eval_valid <= 1;
                        state <= EVALUATE_SUBSETS;
                    end
                end

                EVALUATE_SUBSETS: begin
                    if (subset_idx < limit) begin
                        // Logic to iterate through pieces of the current subset
                        if (piece_selector < num_pieces[2:0]) begin
                            if (subset_idx[piece_selector]) begin
                                // This piece is in the subset
                                if (eval_valid) begin
                                    // Check validity (balance never drops below 0)
                                    // piece_min_prefix is signed 4-bit. Extend to 10-bit signed.
                                    if (curr_bal + $signed({{6{piece_min_prefix[piece_selector][4]}}, piece_min_prefix[piece_selector]}) < 0) begin
                                        eval_valid <= 0;
                                        // Optimization: Skip remaining pieces for this subset
                                        // Move to next subset immediately? Or finish loop.
                                        // Let's just flag invalid and continue to next selector to finish the loop cleanly.
                                        // Actually, to save cycles, let's jump to end logic.
                                        // Since we are in sequential logic, we can jump piece_selector to num_pieces.
                                        piece_selector <= num_pieces[2:0]; 
                                    end else begin
                                        // Update balance and length
                                        curr_bal <= curr_bal + $signed({{6{piece_final_balance[piece_selector][4]}}, piece_final_balance[piece_selector]});
                                        curr_len <= curr_len + piece_len[piece_selector];
                                        piece_selector <= piece_selector + 1;
                                    end
                                end else begin
                                    // Already invalid, skip rest
                                    piece_selector <= num_pieces[2:0];
                                end
                            end else begin
                                // Piece not in subset, skip
                                piece_selector <= piece_selector + 1;
                            end
                        end else begin
                            // Finished evaluating this subset
                            if (eval_valid) begin
                                if (curr_len > max_length) max_length <= curr_len;
                            end
                            // Prepare for next subset
                            subset_idx <= subset_idx + 1;
                            piece_selector <= 0;
                            curr_bal <= 0;
                            curr_len <= 0;
                            eval_valid <= 1;
                        end
                    end else begin
                        // All subsets processed
                        state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1;
                end
            endcase
        end
    end
endmodule
