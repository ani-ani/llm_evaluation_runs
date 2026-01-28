module beach_huts (
    input wire clk,
    input wire rst_n,
    input wire update_en,
    input wire [3:0] hut_idx,
    input wire [15:0] new_val,
    output reg [3:0] optimal_idx,
    output reg done
);

    // State encoding
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] UPDATE_VAL = 3'd1;
    localparam [2:0] CALC_TOTAL = 3'd2;
    localparam [2:0] SCAN       = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] current_idx;
    reg [31:0] total_sum;
    reg [31:0] min_diff;
    reg [3:0] best_idx;
    reg [31:0] left_acc;
    reg [31:0] right_acc;
    reg [3:0] calc_idx;

    // Memory array
    reg [15:0] huts [0:15];

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            optimal_idx <= 4'd0;
            done <= 1'b0;
            current_idx <= 4'd0;
            total_sum <= 32'd0;
            min_diff <= 32'd0;
            best_idx <= 4'd0;
            left_acc <= 32'd0;
            right_acc <= 32'd0;
            calc_idx <= 4'd0;
            
            // Initialize huts array
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                huts[i] <= 16'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
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
                if (calc_idx == 4'd15) begin
                    next_state = SCAN;
                end
            end
            
            SCAN: begin
                if (current_idx == 4'd15) begin
                    next_state = DONE_STATE;
                end
            end
            
            DONE_STATE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already handled in state transition
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                end
                
                UPDATE_VAL: begin
                    huts[hut_idx] <= new_val;
                    calc_idx <= 4'd0;
                    total_sum <= 32'd0;
                    left_acc <= 32'd0;
                end
                
                CALC_TOTAL: begin
                    if (calc_idx == 4'd0) begin
                        total_sum <= huts[0];
                        left_acc <= huts[0];
                    end else begin
                        total_sum <= total_sum + huts[calc_idx];
                        left_acc <= left_acc + huts[calc_idx];
                    end
                    calc_idx <= calc_idx + 4'd1;
                end
                
                SCAN: begin
                    if (current_idx == 4'd0) begin
                        min_diff <= 32'd0;
                        best_idx <= 4'd0;
                    end
                    
                    // Compute left and right sums
                    reg [31:0] current_left;
                    reg [31:0] current_right;
                    reg [31:0] current_diff;
                    
                    if (current_idx == 4'd0) begin
                        current_left = (huts[0] >> 1);
                        current_right = (total_sum - huts[0]) + (huts[0] >> 1);
                    end else begin
                        current_left = left_acc + (huts[current_idx] >> 1);
                        current_right = (total_sum - (left_acc + huts[current_idx])) + (huts[current_idx] >> 1);
                    end
                    
                    current_diff = (current_left > current_right) ? 
                                  (current_left - current_right) : 
                                  (current_right - current_left);
                    
                    // Update min_diff and best_idx
                    if (current_idx == 4'd0 || current_diff < min_diff) begin
                        min_diff <= current_diff;
                        best_idx <= current_idx;
                    end
                    
                    current_idx <= current_idx + 4'd1;
                end
                
                DONE_STATE: begin
                    optimal_idx <= best_idx;
                    done <= 1'b1;
                end
                
                default: begin
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule