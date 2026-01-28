module hedgehog_grey(
    input clk,
    input rst_n,
    input start,
    input [3:0] row_limit,
    input [3:0] col_limit,
    input [15:0] k,
    output reg [15:0] result,
    output reg done
);
    
    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] FINISH  = 2'd2;
    
    // Internal registers
    reg [1:0] state;
    reg [7:0] step_cnt;
    reg [3:0] r;
    reg [3:0] c;
    reg dir;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd260;
    
    // Combinational logic for next state and coordinates
    reg [3:0] next_r;
    reg [3:0] next_c;
    reg next_dir;
    reg [7:0] next_step_cnt;
    reg [15:0] next_result;
    reg next_done;
    
    always @(*) begin
        next_r = r;
        next_c = c;
        next_dir = dir;
        next_step_cnt = step_cnt;
        next_result = result;
        next_done = 1'b0;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_r = 4'd0;
                    next_c = 4'd0;
                    next_dir = 1'b0;
                    next_step_cnt = 8'd0;
                    next_result = 16'd0;
                end
            end
            
            PROCESS: begin
                // Check if current cell is grey
                if ((r & c) == 4'd0) begin
                    next_result = result + 16'd1;
                end else begin
                    next_result = result;
                end
                
                // Update coordinates
                if (dir == 1'b0) begin
                    // Left to Right
                    if (c + 4'd1 < col_limit) begin
                        next_c = c + 4'd1;
                        next_r = r;
                        next_dir = dir;
                    end else begin
                        // Move to next row, change direction
                        if (r + 4'd1 < row_limit) begin
                            next_r = r + 4'd1;
                            next_c = col_limit - 4'd1;
                            next_dir = 1'b1;
                        end else begin
                            // Reached end of grid
                            next_r = r;
                            next_c = c;
                            next_dir = dir;
                        end
                    end
                end else begin
                    // Right to Left
                    if (c > 4'd0) begin
                        next_c = c - 4'd1;
                        next_r = r;
                        next_dir = dir;
                    end else begin
                        // Move to next row, change direction
                        if (r + 4'd1 < row_limit) begin
                            next_r = r + 4'd1;
                            next_c = 4'd0;
                            next_dir = 1'b0;
                        end else begin
                            // Reached end of grid
                            next_r = r;
                            next_c = c;
                            next_dir = dir;
                        end
                    end
                end
                
                // Update step count
                if (step_cnt + 8'd1 < k) begin
                    next_step_cnt = step_cnt + 8'd1;
                end else begin
                    next_step_cnt = step_cnt;
                end
            end
            
            default: begin
                next_r = 4'd0;
                next_c = 4'd0;
                next_dir = 1'b0;
                next_step_cnt = 8'd0;
                next_result = 16'd0;
            end
        endcase
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            step_cnt <= 8'd0;
            r <= 4'd0;
            c <= 4'd0;
            dir <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= PROCESS;
                        r <= 4'd0;
                        c <= 4'd0;
                        dir <= 1'b0;
                        step_cnt <= 8'd0;
                        result <= 16'd0;
                    end
                end
                
                PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Update registers
                    r <= next_r;
                    c <= next_c;
                    dir <= next_dir;
                    step_cnt <= next_step_cnt;
                    result <= next_result;
                    
                    // Check if done
                    if (step_cnt + 8'd1 >= k || cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule