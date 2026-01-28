module beach_huts (
    input wire clk,
    input wire rst_n,
    input wire update_en,
    input wire [3:0] hut_idx,
    input wire [15:0] new_val,
    output reg [3:0] optimal_idx,
    output reg done
);
    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] UPDATE_VAL = 3'd1;
    localparam [2:0] CALC_TOTAL = 3'd2;
    localparam [2:0] SCAN = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    // Registers and arrays
    reg [2:0] state, next_state;
    reg [15:0] huts [0:15];  // Array of 16x16 bits
    reg [31:0] total_sum;
    reg [31:0] min_diff;
    reg [3:0] best_idx;
    reg [3:0] current_idx;
    reg [31:0] left_acc;
    reg [31:0] right_acc;
    reg [31:0] current_left;
    reg [31:0] current_right;
    reg [31:0] diff;
    integer i;

    // State register and reset
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            optimal_idx <= 4'd0;
            done <= 1'b0;
            total_sum <= 32'd0;
            min_diff <= 32'hFFFF_FFFF;
            best_idx <= 4'd0;
            current_idx <= 4'd0;
            left_acc <= 32'd0;
            right_acc <= 32'd0;
            current_left <= 32'd0;
            current_right <= 32'd0;
            diff <= 32'd0;
            for (i = 0; i < 16; i = i + 1) begin
                huts[i] <= 16'd0;
            end
        end else begin
            state <= next_state;
            // Default done clear
            done <= 1'b0;
            case (state)
                UPDATE_VAL: begin
                    huts[hut_idx] <= new_val;
                end
                CALC_TOTAL: begin
                    if (current_idx == 4'd0) begin
                        total_sum <= 32'd0;
                    end
                    total_sum <= total_sum + {16'd0, huts[current_idx]};
                    current_idx <= current_idx + 4'd1;
                end
                SCAN: begin
                    // Compute left and right for current index
                    current_left <= left_acc + ({16'd0, huts[current_idx]} >> 1);
                    current_right <= (total_sum - (left_acc + {16'd0, huts[current_idx]})) + ({16'd0, huts[current_idx]} >> 1);
                    
                    // Update left accumulator for next iteration
                    left_acc <= left_acc + {16'd0, huts[current_idx]};
                    
                    // Check and update best index
                    if (diff < min_diff) begin
                        min_diff <= diff;
                        best_idx <= current_idx;
                    end
                    current_idx <= current_idx + 4'd1;
                end
                DONE_STATE: begin
                    optimal_idx <= best_idx;
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Combinational logic for next state and datapath
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (update_en) begin
                    next_state = UPDATE_VAL;
                end
            end
            UPDATE_VAL: begin
                next_state = CALC_TOTAL;
            end
            CALC_TOTAL: begin
                if (current_idx == 4'd15) begin
                    // Final iteration adds the 15th element
                    next_state = SCAN;
                end else begin
                    next_state = CALC_TOTAL;
                end
            end
            SCAN: begin
                // Calculate diff for current iteration
                if (current_left > current_right) begin
                    diff = current_left - current_right;
                end else begin
                    diff = current_right - current_left;
                end
                
                if (current_idx == 4'd15) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = SCAN;
                end
            end
            DONE_STATE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Reset counters and accumulators when entering new operation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_idx <= 4'd0;
            left_acc <= 32'd0;
            min_diff <= 32'hFFFF_FFFF;
            best_idx <= 4'd0;
        end else begin
            if (state == UPDATE_VAL) begin
                // Prepare for CALC_TOTAL
                current_idx <= 4'd0;
                left_acc <= 32'd0;
                min_diff <= 32'hFFFF_FFFF;
                best_idx <= 4'd0;
            end
        end
    end

endmodule