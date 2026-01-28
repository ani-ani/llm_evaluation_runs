module FindLargestSumElement (
    input wire clk,
    input wire rst_n,
    input wire valid_in,
    input wire start,
    input wire [15:0] arr [0:7],
    output reg [15:0] result,
    output reg done,
    output reg no_solution
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CAPTURE = 3'd1;
    localparam [2:0] INIT_SEARCH = 3'd2;
    localparam [2:0] CHECK_COMBO = 3'd3;
    localparam [2:0] UPDATE_BEST = 3'd4;
    localparam [2:0] NEXT_COMBO = 3'd5;
    localparam [2:0] FINISH = 3'd6;

    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [15:0] arr_reg [0:7];
    reg [3:0] i, j, k, l; // 0-7 indices (4 bits sufficient)
    reg signed [15:0] best_d;
    reg found_flag;
    reg [10:0] cycle_counter; // Max ~1700 cycles for 1680 combinations
    localparam [10:0] MAX_CYCLES = 11'd2000;

    // Synchronous reset and state update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            no_solution <= 1'b0;
            best_d <= 16'h8000; // Min signed 16-bit value
            found_flag <= 1'b0;
            cycle_counter <= 11'd0;
            // Initialize array registers
            arr_reg[0] <= 16'd0;
            arr_reg[1] <= 16'd0;
            arr_reg[2] <= 16'd0;
            arr_reg[3] <= 16'd0;
            arr_reg[4] <= 16'd0;
            arr_reg[5] <= 16'd0;
            arr_reg[6] <= 16'd0;
            arr_reg[7] <= 16'd0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            l <= 4'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    no_solution <= 1'b0;
                    best_d <= 16'h8000;
                    found_flag <= 1'b0;
                    cycle_counter <= 11'd0;
                    i <= 4'd0;
                    j <= 4'd0;
                    k <= 4'd0;
                    l <= 4'd0;
                end
                CAPTURE: begin
                    // Capture inputs when valid
                    if (valid_in) begin
                        arr_reg[0] <= arr[0];
                        arr_reg[1] <= arr[1];
                        arr_reg[2] <= arr[2];
                        arr_reg[3] <= arr[3];
                        arr_reg[4] <= arr[4];
                        arr_reg[5] <= arr[5];
                        arr_reg[6] <= arr[6];
                        arr_reg[7] <= arr[7];
                    end
                end
                CHECK_COMBO: begin
                    // Check distinctness and sum equality
                    // Logic handled in combinational block below
                end
                UPDATE_BEST: begin
                    // Update best_d if condition met
                    if (found_flag && (arr_reg[l] > best_d)) begin
                        best_d <= arr_reg[l];
                    end else if (!found_flag) begin
                        best_d <= arr_reg[l];
                        found_flag <= 1'b1;
                    end
                end
                NEXT_COMBO: begin
                    cycle_counter <= cycle_counter + 11'd1;
                end
                FINISH: begin
                    if (found_flag) begin
                        result <= best_d;
                        no_solution <= 1'b0;
                    end else begin
                        result <= 16'd0;
                        no_solution <= 1'b1;
                    end
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = IDLE;
        case (state)
            IDLE: begin
                if (start && valid_in) next_state = CAPTURE;
                else next_state = IDLE;
            end
            CAPTURE: begin
                next_state = INIT_SEARCH;
            end
            INIT_SEARCH: begin
                next_state = CHECK_COMBO;
            end
            CHECK_COMBO: begin
                // Check if current tuple is valid and calculates sum
                // If valid and sum matches, go to UPDATE_BEST
                // Else go to NEXT_COMBO
                // If all loops finished, go to FINISH
                if (i >= 8) begin
                    next_state = FINISH;
                end else if (j >= 8) begin
                    next_state = FINISH;
                end else if (k >= 8) begin
                    next_state = FINISH;
                end else if (l >= 8) begin
                    next_state = FINISH;
                end else begin
                    // Check distinctness
                    if ((i != j) && (i != k) && (i != l) && 
                        (j != k) && (j != l) && (k != l)) begin
                        // Check sum equality (overflow ignored per spec)
                        if ((arr_reg[i] + arr_reg[j] + arr_reg[k]) == arr_reg[l]) begin
                            next_state = UPDATE_BEST;
                        end else begin
                            next_state = NEXT_COMBO;
                        end
                    end else begin
                        next_state = NEXT_COMBO;
                    end
                end
            end
            UPDATE_BEST: begin
                next_state = NEXT_COMBO;
            end
            NEXT_COMBO: begin
                // Iterate l -> k -> j -> i
                // Logic to increment indices
                // If max cycles exceeded, go to FINISH
                if (cycle_counter >= MAX_CYCLES) next_state = FINISH;
                else next_state = CHECK_COMBO; // Will re-evaluate indices in combinational logic or next cycle
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Combinational logic for index incrementing (needed for NEXT_COMBO)
    // This ensures proper iteration without procedural break
    always @(posedge clk) begin
        if (state == NEXT_COMBO && !rst_n) begin
            // handled in sequential block reset
        end else if (state == NEXT_COMBO && rst_n) begin
            if (l < 8'd7) begin
                l <= l + 4'd1;
            end else begin
                l <= 4'd0;
                if (k < 8'd7) begin
                    k <= k + 4'd1;
                end else begin
                    k <= 4'd0;
                    if (j < 8'd7) begin
                        j <= j + 4'd1;
                    end else begin
                        j <= 4'd0;
                        if (i < 8'd7) begin
                            i <= i + 4'd1;
                        end else begin
                            i <= 4'd8; // Mark as finished
                        end
                    end
                end
            end
        end
    end

endmodule