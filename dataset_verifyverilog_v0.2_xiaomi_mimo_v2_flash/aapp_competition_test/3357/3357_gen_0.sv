module sunlight_hours(
    input clk,
    input rst_n,
    input start,
    input [2:0] n_valid,
    input [15:0] x_data [0:7],
    input [15:0] h_data [0:7],
    output reg [15:0] sun_hours [0:7],
    output reg done
);

    // State definition
    localparam IDLE = 4'd0;
    localparam LOAD = 4'd1;
    localparam SWEEP_WEST = 4'd2;
    localparam SWEEP_EAST = 4'd3;
    localparam CALC = 4'd4;
    localparam DONE = 4'd5;

    // Division States
    localparam DIV_IDLE = 2'd0;
    localparam DIV_RUN = 2'd1;
    localparam DIV_DONE = 2'd2;

    reg [3:0] state;
    reg [2:0] idx, jdx;
    reg [2:0] n_reg;
    reg [15:0] x_reg [0:7];
    reg [15:0] h_reg [0:7];
    reg [31:0] max_slope_west;
    reg [31:0] max_slope_east;

    // Divider registers
    reg [1:0] div_state;
    reg [31:0] div_n;
    reg [15:0] div_d;
    reg [47:0] div_rem;
    reg [31:0] div_quot;
    reg [5:0] div_cnt;

    // Helper logic for pair iteration (combinational wires to help next state)
    wire pair_west_valid = (idx < n_reg - 1) && (jdx < n_reg);
    wire pair_east_valid = (idx > 0) && (jdx >= 0);
    wire signed [15:0] h_diff_w = $signed(h_reg[jdx]) - $signed(h_reg[idx]);
    wire signed [15:0] x_diff_w = $signed(x_reg[jdx]) - $signed(x_reg[idx]);
    wire signed [15:0] h_diff_e = $signed(h_reg[idx]) - $signed(h_reg[jdx]);
    wire signed [15:0] x_diff_e = $signed(x_reg[idx]) - $signed(x_reg[jdx]);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            div_state <= DIV_IDLE;
            max_slope_west <= 32'd0;
            max_slope_east <= 32'd0;
        end else begin
            // --- Division Logic (Parallel to State Machine) ---
            if (div_state == DIV_RUN) begin
                // Shift {div_rem, div_n} left by 1
                // We perform subtraction in the same cycle based on shifted value
                // {div_rem, div_n} is conceptually 80 bits.
                // New remainder candidate = {div_rem[46:0], div_n[31]};
                // New divisor shifted = {div_n[30:0], 1'b0};

                // We need to check if new remainder >= div_d
                // Since div_rem is 48-bit and we shift in from div_n (32-bit),
                // we effectively compare lower 32 bits of the conceptual 80-bit register? 
                // No, we compare the "remainder part" vs div_d.

                // Let's do the shift and compare explicitly.
                // We construct the shifted remainder candidate.
                // div_rem[47:0] holds the remainder. 
                // div_n[31:0] holds the numerator.
                // We shift MSB of div_n into LSB of div_rem? No, we shift the whole register left.
                // Standard logic:
                // Remainder = Remainder << 1; Remainder[0] = Dividend[MSB]; Dividend = Dividend << 1;
                // Check if Remainder >= Divisor.

                // Let's use a temporary variable for the next remainder value.
                // {div_rem, div_n} <= {div_rem[46:0], div_n[31], div_n[30:0], 1'b0};
                // This is a complex concatenation. 
                // Let's break it down.

                // Update div_rem and div_n based on current values.
                // We need to handle the subtraction.

                // Logic:
                // if ({div_rem[46:0], div_n[31]} >= div_d) begin
                //    div_rem <= {div_rem[46:0], div_n[31]} - div_d;
                //    div_quot <= {div_quot[30:0], 1'b1};
                // end else begin
                //    div_rem <= {div_rem[46:0], div_n[31]};
                //    div_quot <= {div_quot[30:0], 1'b0};
                // end
                // div_n <= {div_n[30:0], 1'b0};
                // div_cnt <= div_cnt - 1;

                // Note: div_rem must be wide enough to hold the intermediate value.
                // {div_rem[46:0], div_n[31]} is 48 bits. 
                // div_d is 16 bits. Subtraction fits in 48 bits.

                if ({div_rem[46:0], div_n[31]} >= {32'd0, div_d}) begin
                    div_rem <= {div_rem[46:0], div_n[31]} - {32'd0, div_d};
                    div_quot <= {div_quot[30:0], 1'b1};
                end else begin
                    div_rem <= {div_rem[46:0], div_n[31]};
                    div_quot <= {div_quot[30:0], 1'b0};
                end
                div_n <= {div_n[30:0], 1'b0};

                if (div_cnt == 0) begin
                    div_state <= DIV_DONE;
                end else begin
                    div_cnt <= div_cnt - 1;
                end
            end else begin
                // --- Main State Machine ---
                case (state)
                    IDLE: begin
                        done <= 1'b0;
                        if (start) begin
                            state <= LOAD;
                            n_reg <= n_valid;
                        end
                    end

                    LOAD: begin
                        // Copy inputs
                        x_reg[0] <= x_data[0]; h_reg[0] <= h_data[0];
                        x_reg[1] <= x_data[1]; h_reg[1] <= h_data[1];
                        x_reg[2] <= x_data[2]; h_reg[2] <= h_data[2];
                        x_reg[3] <= x_data[3]; h_reg[3] <= h_data[3];
                        x_reg[4] <= x_data[4]; h_reg[4] <= h_data[4];
                        x_reg[5] <= x_data[5]; h_reg[5] <= h_data[5];
                        x_reg[6] <= x_data[6]; h_reg[6] <= h_data[6];
                        x_reg[7] <= x_data[7]; h_reg[7] <= h_data[7];

                        max_slope_west <= 32'd0;
                        max_slope_east <= 32'd0;
                        idx <= 3'd0;
                        jdx <= 3'd1;

                        if (n_reg > 1)
                            state <= SWEEP_WEST;
                        else
                            state <= CALC;
                    end

                    SWEEP_WEST: begin
                        // Iterate pairs i (idx), j (jdx) where i < j
                        // If h[j] > h[i], calculate slope (h[j]-h[i])/(x[j]-x[i])
                        // If slope > max_slope_west, update.
                        // Advance pair.

                        if (div_state == DIV_DONE) begin
                            // Division finished, update max
                            if (div_quot > max_slope_west) max_slope_west <= div_quot;
                            // Reset div state
                            div_state <= DIV_IDLE;
                            // Advance pair logic below
                        end

                        // Logic to advance pair or start division
                        // If we just updated max (or skipped), we need to move to next pair
                        // But we must check if we need to start a new division for the new pair.

                        // We need to handle the "Start Division" vs "Advance Pointer" logic.
                        // We can do:
                        // 1. Check if current pair needs division. 
                        // 2. If yes, start it.
                        // 3. If no (or done), advance pointer.
                        // 4. Repeat until all pairs done.

                        // But we are in a single state. 
                        // If `div_state` is IDLE, we check current pair.
                        // If valid and needs calculation, start div.
                        // If invalid (handled or end of loop), advance.
                        // If `div_state` is IDLE and we just advanced to an invalid pair, advance again.

                        // Let's implement a step-wise transition.

                        if (pair_west_valid) begin
                            if (h_diff_w > 0 && x_diff_w > 0) begin
                                // Start Division
                                div_n <= h_diff_w[15:0] << 16;
                                div_d <= x_diff_w[15:0];
                                div_rem <= 48'd0;
                                div_quot <= 32'd0;
                                div_cnt <= 6'd31;
                                div_state <= DIV_RUN;
                            end else begin
                                // Skip pair, advance
                                if (jdx < n_reg - 1) jdx <= jdx + 1;
                                else begin
                                    idx <= idx + 1;
                                    jdx <= idx + 2;
                                    if (idx + 1 >= n_reg - 1) begin
                                        // Loop finished for West
                                        state <= SWEEP_EAST;
                                        idx <= n_reg - 1;
                                        jdx <= n_reg - 2;
                                    end
                                end
                            end
                        end else begin
                            // Pair invalid (end of list)
                            state <= SWEEP_EAST;
                            idx <= n_reg - 1;
                            jdx <= n_reg - 2;
                        end
                    end

                    SWEEP_EAST: begin
                        // Iterate pairs i (idx), j (jdx) where i > j
                        // Calculate slope (h[i]-h[j])/(x[i]-x[j])
                        // Note: idx is the "left" building? No, idx is the "source" or target? 
                        // We iterate i from N-1 down to 1. j from i-1 down to 0.
                        // We calculate shadow cast by i on j (Sun from East).
                        // Slope = (h[i] - h[j]) / (x[i] - x[j]).
                        // This is h_diff_e / x_diff_e.

                        if (div_state == DIV_DONE) begin
                            if (div_quot > max_slope_east) max_slope_east <= div_quot;
                            div_state <= DIV_IDLE;
                        end

                        if (pair_east_valid) begin
                             if (h_diff_e > 0 && x_diff_e > 0) begin
                                div_n <= h_diff_e[15:0] << 16;
                                div_d <= x_diff_e[15:0];
                                div_rem <= 48'd0;
                                div_quot <= 32'd0;
                                div_cnt <= 6'd31;
                                div_state <= DIV_RUN;
                             end else begin
                                // Advance (reverse direction)
                                if (jdx > 0) jdx <= jdx - 1;
                                else begin
                                    idx <= idx - 1;
                                    jdx <= idx - 2;
                                    if (idx - 1 <= 0) begin
                                        state <= CALC;
                                    end
                                end
                             end
                        end else begin
                            state <= CALC;
                        end
                    end

                    CALC: begin
                        // Compute Result: 18.0 - (max_slope_west + max_slope_east)
                        // 18.0 = 1179648 (Q16.16)
                        // Result is Q16.16. Output is [15:0]. 
                        // Assuming Output is Integer Part (upper 16 bits of Q16.16 result).
                        // Saturation at 0.

                        // Perform calculation
                        // Note: Using logic inside always block requires explicit variables or blocking assignments usually.
                        // But we can assign to registers directly.

                        // Check sign
                        // Total slope = max_slope_west + max_slope_east
                        // Hours = 1179648 - TotalSlope

                        // To keep it synthesizable and correct, let's compute values.
                        // We can't do array assignment in combinational logic inside always block easily without blocking assignments.
                        // But we are in clocked logic. 

                        // Let's calculate the value to put in the array.
                        // We can use a temp reg or compute inline.

                        // Logic:
                        // if (max_slope_west + max_slope_east < 1179648) 
                        //    final_val = (1179648 - sum) >> 16;
                        // else
                        //    final_val = 0;

                        // Assign to all valid indices.

                        // We need to ensure we only do this once. 
                        // Since CALC is a single state, we transition to DONE next cycle.

                        // Assignments:
                        if (max_slope_west + max_slope_east < 1179648) begin
                            // Subtraction is safe
                            // [15:0] takes the upper 16 bits of the Q16.16 result
                            // 1179648 is 0x120000. 
                            // Sum is some value.
                            // (1179648 - Sum) >> 16 is correct for integer part.

                            // We need to handle the subtraction correctly.
                            // 1179648 is 32-bit. 
                            // Sum is 32-bit.

                            // Let's do the calculation and assign.
                            // Since we need to fill the array, we compute the value once.

                            // Computation:
                            // sun_hours_val = (1179648 - (max_slope_west + max_slope_east)) >> 16;

                            // We can't use >> in assignment to register in always block without blocking? 
                            // Actually we can use blocking for intermediate math.

                            // Let's use blocking assignment for math, then non-blocking for registers.
                            // But `always @(posedge clk)` implies non-blocking usually.
                            // Let's do:
                            // reg [31:0] temp_calc;
                            // temp_calc = 1179648 - (max_slope_west + max_slope_east);
                            // sun_hours[i] <= temp_calc[31:16];

                            // Since I am writing the string, I will write the logic explicitly.

                            // To avoid timing issues or complex logic, I'll just put the calculation in the assignment.
                            // Synthesis will handle the logic.

                            // The subtraction result might be negative if sum > 1179648. 
                            // We checked `if (sum < 1179648)`, so it's positive.

                            // One cycle latency for CALC -> DONE. 
                            // We calculate in CALC, result valid in DONE? 
                            // Or we calculate and set done in same cycle? 
                            // The prompt says "Result valid ... after start".
                            // Let's assume we set outputs and done in CALC state, then go to DONE.

                            // Calculation:
                            // We need to perform the subtraction.
                            // Note: `max_slope_west` is Q16.16 scaled (so 0.5 is 32768).
                            // 18.0 is 1179648.
                            // Result is Q16.16. 
                            // If we want [15:0] as Q16.16, we need 32-bit output. 
                            // But output is 16-bit. 
                            // I will output the Integer Part (Upper 16 bits).

                            // Let's calculate:
                            // reg [31:0] diff = 1179648 - (max_slope_west + max_slope_east);
                            // reg [15:0] val = diff[31:16];

                            // Assign val to array.

                            // We need a temporary variable to compute this.
                            // Since we are inside always block, we can't declare a variable.
                            // We can use a localparam or just inline the logic in the assignment if synthesis allows.
                            // Or, calculate in the previous state (SWEEP_EAST) and store.
                            // Or, calculate now using a wire/logic outside.

                            // Let's use a `calc_result` wire defined outside.
                            // But I can't modify the module header easily.

                            // I will do the math directly in the assignment expression.
                            // SystemVerilog allows expressions in non-blocking assignments.

                            // Note: 1179648 is 32'h00120000.
                            // Let's define it.

                            // The code for CALC state:
                            // Calculate integer hours.
                            // If the result is fractional (e.g. 17.5), we truncate or round? 
                            // Truncate is standard for integer output.

                            // Wait, if slope is 0.5 (32768), and we have two sides (1.0 total), 18 - 1.0 = 17.0.
                            // (18 * 65536 - 1 * 65536) / 65536 = 17.
                            // So `max_slope` values are already scaled.
                            // So `max_slope` + `max_slope` is in 65536 units.
                            // So (1179648 - sum) is in 65536 units.
                            // `sun_hours` is [15:0], likely meaning we want the value as an integer.
                            // So we shift right by 16.

                            // Let's verify the prompt types again: `output reg [15:0] sun_hours [0:7] // Result in Q16.16 format`.
                            // This is a contradiction (16-bit reg can't hold Q16.16). 
                            // I will assume the comment is misleading and the intent is a 16-bit integer result (hours).
                            // 18 hours fits in 5 bits. 

                            // Implementation:
                            // sun_hours[0] <= ( (32'h120000 - (max_slope_west + max_slope_east)) >> 16 );
                            // This is valid SV syntax for synthesis.

                            // However, `max_slope_west` might be large. 
                            // We handled `if (max_slope_west + max_slope_east < 32'h120000)`.

                            // Let's write the assignments.

                            // Assign to array (only valid indices)
                            // We need to loop 0 to 7. 
                            // Unrolled:
                            if (0 < n_reg) sun_hours[0] <= (32'h120000 - (max_slope_west + max_slope_east)) >> 16;
                            if (1 < n_reg) sun_hours[1] <= (32'h120000 - (max_slope_west + max_slope_east)) >> 16;
                            if (2 < n_reg) sun_hours[2] <= (32'h120000 - (max_slope_west + max_slope_east)) >> 16;
                            if (3 < n_reg) sun_hours[3] <= (32'h120000 - (max_slope_west + max_slope_east)) >> 16;
                            if (4 < n_reg) sun_hours[4] <= (32'h120000 - (max_slope_west + max_slope_east)) >> 16;
                            if (5 < n_reg) sun_hours[5] <= (32'h120000 - (max_slope_west + max_slope_east)) >> 16;
                            if (6 < n_reg) sun_hours[6] <= (32'h120000 - (max_slope_west + max_slope_east)) >> 16;
                            if (7 < n_reg) sun_hours[7] <= (32'h120000 - (max_slope_west + max_slope_east)) >> 16;

                            // For invalid indices, set 0
                            if (0 >= n_reg) sun_hours[0] <= 16'd0;
                            if (1 >= n_reg) sun_hours[1] <= 16'd0;
                            if (2 >= n_reg) sun_hours[2] <= 16'd0;
                            if (3 >= n_reg) sun_hours[3] <= 16'd0;
                            if (4 >= n_reg) sun_hours[4] <= 16'd0;
                            if (5 >= n_reg) sun_hours[5] <= 16'd0;
                            if (6 >= n_reg) sun_hours[6] <= 16'd0;
                            if (7 >= n_reg) sun_hours[7] <= 16'd0;
                        end else begin
                            // Saturate to 0
                            sun_hours[0] <= 16'd0;
                            sun_hours[1] <= 16'd0;
                            sun_hours[2] <= 16'd0;
                            sun_hours[3] <= 16'd0;
                            sun_hours[4] <= 16'd0;
                            sun_hours[5] <= 16'd0;
                            sun_hours[6] <= 16'd0;
                            sun_hours[7] <= 16'd0;
                        end

                        done <= 1'b1;
                        state <= DONE;
                    end

                    DONE: begin
                        if (~start) begin
                            state <= IDLE;
                            done <= 1'b0;
                        end
                    end
                endcase
            end
        end
    end
endmodule