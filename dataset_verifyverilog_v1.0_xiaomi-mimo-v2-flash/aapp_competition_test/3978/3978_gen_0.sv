module color_computation(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [6:0] a_i,
    input [3:0] addr_wr,
    input wr_en,
    output reg [4:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] LOAD    = 3'd1;
    localparam [2:0] SORT    = 3'd2;
    localparam [2:0] COUNT   = 3'd3;
    localparam [2:0] DIVIDE  = 3'd4;
    localparam [2:0] DONE    = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] n_reg;
    reg [6:0] arr [0:15];
    reg [6:0] arr_temp [0:15]; // For sorting
    reg [3:0] i_idx, j_idx, k_idx;
    reg [6:0] temp_val;
    reg [6:0] divisor, dividend;
    reg [6:0] remainder;
    reg [6:0] quotient;
    reg div_done;
    reg [4:0] color_count;
    reg [15:0] used; // 16 bits for 16 elements
    reg [4:0] cycle_count;
    localparam [4:0] MAX_CYCLES = 5'd20;

    // Modulo/division logic registers
    reg [6:0] div_rem;
    reg [3:0] div_bit;

    integer idx;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 5'd0;
            done <= 1'b0;
            n_reg <= 4'd0;
            for (idx = 0; idx < 16; idx = idx + 1) begin
                arr[idx] <= 7'd0;
                arr_temp[idx] <= 7'd0;
            end
            i_idx <= 4'd0;
            j_idx <= 4'd0;
            k_idx <= 4'd0;
            temp_val <= 7'd0;
            divisor <= 7'd0;
            dividend <= 7'd0;
            remainder <= 7'd0;
            quotient <= 7'd0;
            div_done <= 1'b0;
            color_count <= 5'd0;
            used <= 16'd0;
            cycle_count <= 5'd0;
            div_rem <= 7'd0;
            div_bit <= 4'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 5'd0;
                    cycle_count <= 5'd0;
                    if (start) begin
                        n_reg <= (n > 4'd15) ? 4'd15 : n; // Cap n at 16
                    end
                end

                LOAD: begin
                    if (wr_en && addr_wr < n_reg) begin
                        arr[addr_wr] <= a_i;
                        arr_temp[addr_wr] <= a_i;
                    end
                end

                SORT: begin
                    // Bubble sort pass
                    if (j_idx < n_reg - 4'd1) begin
                        if (arr_temp[j_idx] > arr_temp[j_idx + 4'd1]) begin
                            temp_val <= arr_temp[j_idx];
                            arr_temp[j_idx] <= arr_temp[j_idx + 4'd1];
                            arr_temp[j_idx + 4'd1] <= temp_val;
                        end
                        j_idx <= j_idx + 4'd1;
                    end else begin
                        j_idx <= 4'd0;
                        i_idx <= i_idx + 4'd1;
                        if (i_idx >= n_reg - 4'd2) begin
                            // Copy sorted back to arr
                            for (idx = 0; idx < 16; idx = idx + 1) begin
                                if (idx < n_reg) arr[idx] <= arr_temp[idx];
                            end
                        end
                    end
                end

                COUNT: begin
                    if (i_idx < n_reg) begin
                        if (used[i_idx] == 1'b0) begin
                            color_count <= color_count + 5'd1;
                            used[i_idx] <= 1'b1;
                            j_idx <= i_idx + 4'd1;
                        end else begin
                            i_idx <= i_idx + 4'd1;
                        end
                    end
                end

                DIVIDE: begin
                    // Perform arr[j] % arr[i] using sequential subtraction
                    if (divisor != 7'd0) begin
                        if (dividend >= divisor) begin
                            dividend <= dividend - divisor;
                            quotient <= quotient + 7'd1;
                        end else begin
                            remainder <= dividend;
                            div_done <= 1'b1;
                        end
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    result <= color_count;
                end
            endcase

            // Cycle counter for safety
            if (state != IDLE && state != DONE) begin
                cycle_count <= cycle_count + 5'd1;
            end
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = LOAD;
            end

            LOAD: begin
                // Assume sequential loading is complete when n cycles pass
                // For simplicity, assume done in same cycle (req: wr_en logic controlled externally)
                next_state = SORT;
            end

            SORT: begin
                // Bubble sort complete when i_idx >= n_reg - 2
                if (n_reg <= 4'd1) next_state = COUNT;
                else if (i_idx >= n_reg - 4'd2 && j_idx >= n_reg - 4'd1) next_state = COUNT;
                else next_state = SORT;
            end

            COUNT: begin
                if (i_idx >= n_reg) next_state = DONE;
                else if (used[i_idx] == 1'b0) next_state = DIVIDE;
                else next_state = COUNT;
            end

            DIVIDE: begin
                if (div_done) begin
                    // Check remainder
                    if (remainder == 7'd0) begin
                        // Divisible, mark used
                        if (j_idx < n_reg) next_state = COUNT; // Continue inner loop
                        else next_state = COUNT; // Back to outer
                    end else begin
                        // Not divisible
                        if (j_idx < n_reg) next_state = COUNT; // Continue inner loop
                        else next_state = COUNT;
                    end
                end else begin
                    next_state = DIVIDE;
                end
            end

            DONE: next_state = IDLE;

            default: next_state = IDLE;
        endcase
    end

    // Control logic for transitions between states
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled above
        end else begin
            if (state == COUNT && next_state == DIVIDE) begin
                // Initialize division
                divisor <= arr[i_idx];
                dividend <= arr[j_idx];
                quotient <= 7'd0;
                remainder <= 7'd0;
                div_done <= 1'b0;
            end else if (state == DIVIDE && next_state == COUNT) begin
                // Division finished, process result
                if (remainder == 7'd0) begin
                    used[j_idx] <= 1'b1;
                end
                j_idx <= j_idx + 4'd1;
                if (j_idx + 4'd1 >= n_reg) begin
                    i_idx <= i_idx + 4'd1;
                end
                div_done <= 1'b0;
            end
        end
    end

endmodule