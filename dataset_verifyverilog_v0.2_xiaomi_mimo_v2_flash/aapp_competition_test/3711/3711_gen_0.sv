module chocolate_cutter (
    input clk,
    input rst_n,
    input start,
    input [9:0] n,
    input [9:0] m,
    input [9:0] k,
    output reg [39:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam CHECK_VALIDITY = 3'b001;
    localparam CALCULATE_Y = 3'b010;
    localparam CALCULATE_WIDTH = 3'b011;
    localparam CALCULATE_HEIGHT = 3'b100;
    localparam CALCULATE_AREA = 3'b101;
    localparam UPDATE_RESULT = 3'b110;
    localparam DONE = 3'b111;

    reg [2:0] state;
    reg [2:0] next_state;

    // Internal registers
    reg [9:0] x_reg;              // Current x value
    reg [9:0] y_reg;              // Current y value
    reg [39:0] max_area_reg;      // Stores the maximum area found
    reg [39:0] current_area_reg;  // Temporary for calculation
    
    // Combinational intermediate values for calculation
    wire [39:0] width_val;
    wire [39:0] height_val;
    wire [39:0] area_val;
    
    // Division and Multiplication Logic (Combinational)
    // n, m are max 10 bits, x+1 and y+1 are max 10 bits.
    // Result needs 40 bits to hold max area (1023*1023 approx 10^6, but scale to 40 bits as requested).
    assign width_val = (x_reg < n) ? (n / (x_reg + 1)) : 0;
    assign height_val = (y_reg < m) ? (m / (y_reg + 1)) : 0;
    assign area_val = width_val * height_val;

    // State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next State Logic & Datapath
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
            result <= 40'd0;
            x_reg <= 10'd0;
            y_reg <= 10'd0;
            max_area_reg <= 40'd0;
            current_area_reg <= 40'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        x_reg <= 10'd0;
                        max_area_reg <= 40'd0;
                    end
                end

                CHECK_VALIDITY: begin
                    // Impossibility check: if k > (n-1) + (m-1). 
                    // Since inputs are 10 bits, max sum is 2042. Use wider wire or check carefully.
                    // Using combinational check in next_state logic, but we set result here if invalid.
                    if (k > (n - 1) + (m - 1)) begin
                        result <= 40'hFFFF_FFFF_FFFF; // -1
                    end else begin
                        // Reset max area to 0 for valid case (though technically area can be 0 if n=0, but n>=1)
                        max_area_reg <= 40'd0; 
                    end
                end

                CALCULATE_Y: begin
                    // Calculate y = k - x
                    y_reg <= k - x_reg;
                end

                CALCULATE_WIDTH: begin
                    // Wait state for combinational logic to settle (optional but good practice)
                    // Or we can skip if timing allows. Here we just proceed to CALCULATE_HEIGHT.
                    // Actual width calculation is combinational on x_reg.
                end

                CALCULATE_HEIGHT: begin
                    // Actual height calculation is combinational on y_reg.
                end

                CALCULATE_AREA: begin
                    // Latch the calculated area
                    current_area_reg <= area_val;
                end

                UPDATE_RESULT: begin
                    if (current_area_reg > max_area_reg) begin
                        max_area_reg <= current_area_reg;
                    end
                    // Increment x for next iteration
                    x_reg <= x_reg + 1;
                end

                DONE: begin
                    if (k <= (n - 1) + (m - 1)) begin
                        result <= max_area_reg;
                    end
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Next State Combination Logic
    always @(*) begin
        next_state = state; // Default stay in current state
        case (state)
            IDLE: begin
                if (start) begin
                    // If k is 0, we can skip validity check or handle it. 
                    // Let's go to check validity to handle edge cases (e.g. k=0 is valid).
                    // But if k=0, max x is 0. We need to handle loop logic.
                    // The problem says iterate x from 0 to min(k, n-1).
                    next_state = CHECK_VALIDITY;
                end
            end

            CHECK_VALIDITY: begin
                if (k > (n - 1) + (m - 1)) begin
                    next_state = DONE;
                end else begin
                    // If k=0, x=0 is the only iteration.
                    // However, if k=0, we might want to calculate immediately.
                    // The loop starts at x=0. We need to calculate y first.
                    next_state = CALCULATE_Y;
                end
            end

            CALCULATE_Y: begin
                // Check validity of y (y <= m-1)
                // y_reg = k - x_reg
                // Also check if x_reg <= k (though loop condition handles this)
                // Loop condition: x <= min(k, n-1)
                if (x_reg > k || x_reg >= n) begin
                    next_state = DONE; // Should have stopped earlier
                end else if (y_reg > m - 1) begin
                    // Invalid y, skip this iteration
                    next_state = UPDATE_RESULT; // Update will increment x
                end else begin
                    next_state = CALCULATE_WIDTH;
                end
            end

            CALCULATE_WIDTH: begin
                next_state = CALCULATE_HEIGHT;
            end

            CALCULATE_HEIGHT: begin
                next_state = CALCULATE_AREA;
            end

            CALCULATE_AREA: begin
                next_state = UPDATE_RESULT;
            end

            UPDATE_RESULT: begin
                // Loop termination check: Is next x valid? 
                // Loop runs for x from 0 to min(k, n-1).
                // So if (x_reg + 1) > min(k, n-1), we are done.
                // Check: (x_reg + 1) > k OR (x_reg + 1) >= n
                if ((x_reg + 1) > k || (x_reg + 1) >= n) begin
                    next_state = DONE;
                end else begin
                    next_state = CALCULATE_Y;
                end
            end

            DONE: begin
                if (!start) begin
                    next_state = IDLE;
                end
            end

            default: next_state = IDLE;
        endcase
    end

endmodule
