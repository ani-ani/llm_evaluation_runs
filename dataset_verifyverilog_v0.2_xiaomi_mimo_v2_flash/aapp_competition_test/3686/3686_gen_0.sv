module collinear_checker (
    input clk,
    input rst_n,
    input start,
    input [7:0] point_x [0:15],
    input [7:0] point_y [0:15],
    input [4:0] num_points,
    output reg success,
    output reg done
);

    // States
    localparam IDLE = 3'b000;
    localparam CHECK_COLLINEAR = 3'b001;
    localparam STRATEGY_A = 3'b010;
    localparam STRATEGY_B = 3'b011;
    localparam STRATEGY_C = 3'b100;
    localparam VERIFY_REMAINING = 3'b101;
    localparam DONE = 3'b110;
    // 3'b111 is used as a helper state for math checking and branching

    reg [2:0] state;
    reg [1:0] strategy_attempt;
    reg [4:0] cnt;
    reg [3:0] rem_cnt;
    reg [4:0] rem_list [0:15];
    reg calc_phase; // 0: sub, 1: mul
    reg check_mode; // 0: initial check, 1: strategy check, 2: verify check
    
    // Math regs
    reg signed [9:0] dx1, dy1, dx2, dy2;
    reg signed [18:0] prod1, prod2;
    
    // Combinational helper
    wire signed [9:0] cx = $signed({1'b0, point_x[cnt]});
    wire signed [9:0] cy = $signed({1'b0, point_y[cnt]});
    wire match = (prod1 == prod2);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            success <= 0;
        end else begin
            done <= 0;
            calc_phase <= ~calc_phase; // Toggle by default
            
            case (state)
                IDLE: begin
                    calc_phase <= 0;
                    if (start) begin
                        if (num_points < 3) begin
                            success <= 1; done <= 1; state <= DONE;
                        end else begin
                            cnt <= 3;
                            check_mode <= 0;
                            state <= CHECK_COLLINEAR;
                        end
                    end
                end

                // --- Initial Check ---
                CHECK_COLLINEAR: begin
                    if (calc_phase == 0) begin
                        dx1 <= $signed({1'b0, point_x[1]}) - $signed({1'b0, point_x[0]});
                        dy1 <= $signed({1'b0, point_y[1]}) - $signed({1'b0, point_y[0]});
                        dx2 <= cx - $signed({1'b0, point_x[0]});
                        dy2 <= cy - $signed({1'b0, point_y[0]});
                    end else begin
                        prod1 <= dx1 * dy2;
                        prod2 <= dx2 * dy1;
                        state <= 3'b111; // Jump to checker
                        cnt <= cnt + 1;
                    end
                end

                // --- Strategy A ---
                STRATEGY_A: begin
                    if (calc_phase == 0) begin
                        dx1 <= $signed({1'b0, point_x[1]}) - $signed({1'b0, point_x[0]});
                        dy1 <= $signed({1'b0, point_y[1]}) - $signed({1'b0, point_y[0]});
                        dx2 <= cx - $signed({1'b0, point_x[0]});
                        dy2 <= cy - $signed({1'b0, point_y[0]});
                    end else begin
                        prod1 <= dx1 * dy2;
                        prod2 <= dx2 * dy1;
                        state <= 3'b111;
                        cnt <= cnt + 1;
                    end
                end

                // --- Strategy B ---
                STRATEGY_B: begin
                    if (calc_phase == 0) begin
                        dx1 <= $signed({1'b0, point_x[2]}) - $signed({1'b0, point_x[0]});
                        dy1 <= $signed({1'b0, point_y[2]}) - $signed({1'b0, point_y[0]});
                        dx2 <= cx - $signed({1'b0, point_x[0]});
                        dy2 <= cy - $signed({1'b0, point_y[0]});
                    end else begin
                        prod1 <= dx1 * dy2;
                        prod2 <= dx2 * dy1;
                        state <= 3'b111;
                        cnt <= cnt + 1;
                    end
                end

                // --- Strategy C ---
                STRATEGY_C: begin
                    if (calc_phase == 0) begin
                        dx1 <= $signed({1'b0, point_x[2]}) - $signed({1'b0, point_x[1]});
                        dy1 <= $signed({1'b0, point_y[2]}) - $signed({1'b0, point_y[1]});
                        dx2 <= cx - $signed({1'b0, point_x[1]});
                        dy2 <= cy - $signed({1'b0, point_y[1]});
                    end else begin
                        prod1 <= dx1 * dy2;
                        prod2 <= dx2 * dy1;
                        state <= 3'b111;
                        cnt <= cnt + 1;
                    end
                end

                // --- Verify Remaining ---
                VERIFY_REMAINING: begin
                    if (calc_phase == 0) begin
                        // Base points: rem_list[0], rem_list[1]
                        // Check point: rem_list[cnt]
                        // Use rem_cnt as loop limit, cnt as index counter
                        if (cnt < rem_cnt) begin
                            dx1 <= $signed({1'b0, point_x[rem_list[1]]}) - $signed({1'b0, point_x[rem_list[0]]});
                            dy1 <= $signed({1'b0, point_y[rem_list[1]]}) - $signed({1'b0, point_y[rem_list[0]]});
                            dx2 <= $signed({1'b0, point_x[rem_list[cnt]]}) - $signed({1'b0, point_x[rem_list[0]]});
                            dy2 <= $signed({1'b0, point_y[rem_list[cnt]]}) - $signed({1'b0, point_y[rem_list[0]]});
                        end
                    end else begin
                        if (cnt < rem_cnt) begin
                            prod1 <= dx1 * dy2;
                            prod2 <= dx2 * dy1;
                            state <= 3'b111;
                            cnt <= cnt + 1;
                        end else begin
                            // Loop finished, all matched
                            success <= 1; done <= 1; state <= DONE;
                        end
                    end
                end

                // --- Checker / Brancher (State 111) ---
                3'b111: begin
                    // We check 'match' (prod1 vs prod2) from previous state
                    if (!match) begin
                        // Mismatch logic depends on check_mode
                        if (check_mode == 0) begin
                            // Initial Check failed
                            strategy_attempt <= 0;
                            rem_cnt <= 0;
                            cnt <= 3; // Loop from index 3 in strategies
                            state <= STRATEGY_A;
                        end else if (check_mode == 1) begin
                            // Strategy Marking failed (point not on line)
                            // Record index (cnt - 1)
                            rem_list[rem_cnt] <= cnt - 1;
                            rem_cnt <= rem_cnt + 1;
                            
                            // Check loop end for strategy marking
                            if (cnt == num_points) begin
                                // Finished marking, check remaining
                                if (rem_cnt < 2) begin // 0 or 1 remaining points
                                    success <= 1; done <= 1; state <= DONE;
                                end else begin
                                    // Need to verify
                                    cnt <= 2; // Start from 3rd remaining point
                                    state <= VERIFY_REMAINING;
                                end
                            end else begin
                                // Continue strategy loop (no action needed, just return to strategy state)
                                state <= (strategy_attempt == 0) ? STRATEGY_A : 
                                         (strategy_attempt == 1) ? STRATEGY_B : STRATEGY_C;
                            end
                        end else begin
                            // Verify Check failed (point not on line)
                            // This strategy failed completely
                            strategy_attempt <= strategy_attempt + 1;
                            rem_cnt <= 0;
                            cnt <= 3;
                            if (strategy_attempt == 0) state <= STRATEGY_B;
                            else if (strategy_attempt == 1) state <= STRATEGY_C;
                            else begin success <= 0; done <= 1; state <= DONE; end
                        end
                    end else begin
                        // Match logic
                        if (check_mode == 0) begin
                            // Initial Check Match
                            if (cnt == num_points) begin success <= 1; done <= 1; state <= DONE; end
                            else state <= CHECK_COLLINEAR;
                        end else if (check_mode == 1) begin
                            // Strategy Marking Match
                            if (cnt == num_points) begin
                                if (rem_cnt < 2) begin success <= 1; done <= 1; state <= DONE; end
                                else begin cnt <= 2; state <= VERIFY_REMAINING; end
                            end else begin
                                state <= (strategy_attempt == 0) ? STRATEGY_A : 
                                         (strategy_attempt == 1) ? STRATEGY_B : STRATEGY_C;
                            end
                        end else begin
                            // Verify Match
                            if (cnt == rem_cnt) begin success <= 1; done <= 1; state <= DONE; end
                            else state <= VERIFY_REMAINING;
                        end
                    end
                end

                DONE: begin
                    // Keep outputs
                end
            endcase
        end
    end

    // Update check_mode based on state
    always @(*) begin
        if (state == CHECK_COLLINEAR) check_mode = 0;
        else if (state == STRATEGY_A || state == STRATEGY_B || state == STRATEGY_C) check_mode = 1;
        else if (state == VERIFY_REMAINING) check_mode = 2;
        else check_mode = check_mode; // Keep
    end

endmodule