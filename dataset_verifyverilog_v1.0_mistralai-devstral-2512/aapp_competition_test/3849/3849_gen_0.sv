module card_game_winner(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [3:0] k,
    input [15:0] state,
    output reg [1:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] COMPUTE = 3'd1;
    localparam [2:0] FINISH  = 3'd2;
    
    reg [2:0] current_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd20;

    // Internal signals for computation
    reg [15:0] temp_state;
    reg [3:0] i, j;
    reg [15:0] window_mask;
    reg [15:0] flipped_state;
    reg [15:0] all_zeros, all_ones;
    reg tokitsukaze_wins;
    reg quailty_wins;
    reg once_again;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            result <= 2'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            i <= 4'd0;
            j <= 4'd0;
            temp_state <= 16'd0;
            window_mask <= 16'd0;
            flipped_state <= 16'd0;
            all_zeros <= 16'd0;
            all_ones <= 16'd0;
            tokitsukaze_wins <= 1'b0;
            quailty_wins <= 1'b0;
            once_again <= 1'b0;
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        current_state <= COMPUTE;
                        temp_state <= state;
                        all_zeros <= 16'd0;
                        all_ones <= 16'd0;
                        i <= 4'd0;
                        j <= 4'd0;
                        tokitsukaze_wins <= 1'b0;
                        quailty_wins <= 1'b0;
                        once_again <= 1'b0;
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;

                    // Check if k >= n-1 (immediate win)
                    if (k >= n - 1) begin
                        tokitsukaze_wins <= 1'b1;
                        current_state <= FINISH;
                    end
                    // Check if k < n / 2 (once again)
                    else if (k < (n >> 1)) begin
                        once_again <= 1'b1;
                        current_state <= FINISH;
                    end
                    else begin
                        // Check for Tokitsukaze win condition
                        if (!tokitsukaze_wins) begin
                            // Generate window mask
                            window_mask <= {16{1'b0}};
                            for (j = 0; j < k; j = j + 1) begin
                                window_mask[j] <= 1'b1;
                            end

                            // Check all possible windows
                            for (i = 0; i <= n - k; i = i + 1) begin
                                // Flip window to 0s
                                flipped_state <= temp_state ^ (window_mask << i);
                                if (flipped_state == all_zeros) begin
                                    tokitsukaze_wins <= 1'b1;
                                end
                                // Flip window to 1s
                                flipped_state <= temp_state ^ ((~window_mask) << i);
                                if (flipped_state == all_ones) begin
                                    tokitsukaze_wins <= 1'b1;
                                end
                            end

                            if (tokitsukaze_wins) begin
                                current_state <= FINISH;
                            end else begin
                                // Check for Quailty win condition
                                quailty_wins <= 1'b1;
                                current_state <= FINISH;
                            end
                        end
                    end

                    // Exit conditions
                    if (tokitsukaze_wins || quailty_wins || once_again || cycle_count >= MAX_CYCLES) begin
                        current_state <= FINISH;
                    end
                end

                FINISH: begin
                    if (tokitsukaze_wins) begin
                        result <= 2'd0;  // tokitsukaze
                    end else if (quailty_wins) begin
                        result <= 2'd1;  // quailty
                    end else begin
                        result <= 2'd2;  // once_again
                    end
                    done <= 1'b1;
                    current_state <= IDLE;
                end

                default: current_state <= IDLE;
            endcase
        end
    end

    // Precompute all_zeros and all_ones
    always @(*) begin
        all_zeros = 16'd0;
        all_ones = {16{1'b1}};
    end

endmodule