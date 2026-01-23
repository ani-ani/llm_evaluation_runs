module m_perfect_solver(
    input clk,
    input rst_n,
    input start,
    input [31:0] x_in,
    input [31:0] y_in,
    input [31:0] m_in,
    output reg [31:0] result,
    output reg done
);

    // States
    localparam IDLE = 0;
    localparam CHECK_INIT = 1;
    localparam NEGATIVE_FIX = 2;
    localparam COMPUTE_LOOP = 3;
    localparam DONE = 4;

    reg [3:0] state;
    
    // Computation registers
    reg signed [31:0] x;
    reg signed [31:0] y;
    reg signed [31:0] m;
    reg signed [31:0] ops;
    reg [5:0] loop_limit; // Max 50

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        x <= x_in;
                        y <= y_in;
                        m <= m_in;
                        ops <= 32'd0;
                        loop_limit <= 6'd0;
                        state <= CHECK_INIT;
                    end
                end

                CHECK_INIT: begin
                    // Check if already perfect
                    if ((x >= m) || (y >= m)) begin
                        result <= 32'd0;
                        done <= 1'b1;
                        state <= DONE;
                    end
                    // Check impossible (both non-positive and m positive)
                    else if (x <= 32'sd0 && y <= 32'sd0 && m > 32'sd0) begin
                        result <= -32'sd1;
                        done <= 1'b1;
                        state <= DONE;
                    end
                    // Check for negative fix requirement
                    else if ((x < 32'sd0 && y > 32'sd0) || (y < 32'sd0 && x > 32'sd0)) begin
                        state <= NEGATIVE_FIX;
                    end
                    // Otherwise, proceed to loop (including cases where both negative but m negative, which are handled in loop)
                    else begin
                        state <= COMPUTE_LOOP;
                    end
                end

                NEGATIVE_FIX: begin
                    // Perform one addition per cycle
                    if (x < 32'sd0 && y > 32'sd0) begin
                        x <= x + y;
                        ops <= ops + 1;
                        if (x + y >= 32'sd0) begin
                            state <= COMPUTE_LOOP;
                        end else begin
                            state <= NEGATIVE_FIX;
                        end
                    end else if (y < 32'sd0 && x > 32'sd0) begin
                        y <= y + x;
                        ops <= ops + 1;
                        if (y + x >= 32'sd0) begin
                            state <= COMPUTE_LOOP;
                        end else begin
                            state <= NEGATIVE_FIX;
                        end
                    end else begin
                        // Should not reach here if logic is correct, but safe fallback
                        state <= COMPUTE_LOOP;
                    end
                end

                COMPUTE_LOOP: begin
                    // 1. Check termination condition (max >= m)
                    // We check using current x and y before swapping/updates
                    if ((x >= m) || (y >= m)) begin
                        result <= ops;
                        done <= 1'b1;
                        state <= DONE;
                    end else if (loop_limit > 50) begin
                        // Safety break
                        result <= -32'sd1;
                        done <= 1'b1;
                        state <= DONE;
                    end else begin
                        // 2. Ensure x <= y (swap if x > y)
                        // Using non-blocking assignment for swap works correctly in hardware
                        if (x > y) begin
                            x <= y;
                            y <= x;
                        end
                        
                        // 3. Check impossible condition (y <= 0)
                        // Note: We check after potential swap. If x > y, we swap, so y becomes max(x,y).
                        // If max <= 0 and m > max (since we passed the first check), impossible.
                        // If m <= 0, and max <= 0, if max >= m we would be done. 
                        // So if we are here, max < m.
                        // If max <= 0, we cannot reach m (since x+y <= max).
                        // So check y <= 0.
                        // However, we need to use the updated y if we swapped.
                        // But wait, we can't use `if (y <= 0)` inside the same block because `y` was assigned conditionally.
                        // Actually, we can't check the *new* y value in this cycle.
                        // We need to check the *old* max value? Or check in next state?
                        // To keep latency low, let's restructure.
                        
                        // Refined COMPUTE_LOOP logic:
                        // Pre-calculate max and min.
                        // If max >= m -> DONE.
                        // If max <= 0 -> DONE -1 (impossible).
                        // Update: x = max, y = max + min.
                        // ops++.
                        
                        // Let's use `temp_x` as `max`, `temp_y` as `min`.
                        // `temp_x <= (x > y) ? x : y;`
                        // `temp_y <= (x > y) ? y : x;`
                        // Then next cycle we can check and update.
                        // But that adds a cycle.
                        
                        // Let's try to do it in one cycle by checking the OLD values correctly.
                        // If x > y:
                        //   max is x
                        //   Check x >= m? 
                        //   Check x <= 0?
                        //   Update: new_x = x, new_y = x+y.
                        // If y >= x:
                        //   max is y
                        //   Check y >= m?
                        //   Check y <= 0?
                        //   Update: new_x = y, new_y = x+y.
                        
                        // This requires multiple branches.
                        // Let's do it cleanly:
                        
                        if (x > y) begin
                            // max is x
                            if (x >= m) begin
                                result <= ops;
                                done <= 1'b1;
                                state <= DONE;
                            end else if (x <= 32'sd0) begin // m > x (from above), so impossible
                                result <= -32'sd1;
                                done <= 1'b1;
                                state <= DONE;
                            end else begin
                                // Update
                                x <= y;
                                y <= x + y;
                                ops <= ops + 1;
                                loop_limit <= loop_limit + 1;
                                state <= COMPUTE_LOOP;
                            end
                        end else begin
                            // max is y
                            if (y >= m) begin
                                result <= ops;
                                done <= 1'b1;
                                state <= DONE;
                            end else if (y <= 32'sd0) begin
                                result <= -32'sd1;
                                done <= 1'b1;
                                state <= DONE;
                            end else begin
                                // No swap needed (x <= y is true)
                                // Update: x = y, y = x + y (old values)
                                x <= y;
                                y <= x + y;
                                ops <= ops + 1;
                                loop_limit <= loop_limit + 1;
                                state <= COMPUTE_LOOP;
                            end
                        end
                    end
                end

                DONE: begin
                    // Latch result and done
                    done <= 1'b1;
                    // Wait for reset or start
                    if (start) begin
                        // Restart if start comes in (optional behavior, but good for flow)
                        x <= x_in;
                        y <= y_in;
                        m <= m_in;
                        ops <= 32'd0;
                        loop_limit <= 6'd0;
                        state <= CHECK_INIT;
                        done <= 1'b0;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule