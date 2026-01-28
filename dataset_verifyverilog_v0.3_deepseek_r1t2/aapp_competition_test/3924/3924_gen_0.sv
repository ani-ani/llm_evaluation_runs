module garbage_disposal(
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    input [7:0] k,
    input [7:0] a_0,
    input [7:0] a_1,
    input [7:0] a_2,
    input [7:0] a_3,
    input [7:0] a_4,
    input [7:0] a_5,
    input [7:0] a_6,
    input [7:0] a_7,
    output reg [15:0] bags,
    output reg done
);
    
    // State declarations
    localparam [1:0] IDLE     = 2'd0;
    localparam [1:0] PROCESS  = 2'd1;
    localparam [1:0] FINISH   = 2'd2;
    localparam [1:0] DONE_ST  = 2'd3;
    
    reg [1:0] state, next_state;
    reg [7:0] day_cnt;
    reg [7:0] leftover;
    
    // Garbage selection reg
    reg [7:0] current_garbage;
    
    // Computation intermediates
    reg [7:0] bags_needed;
    reg [7:0] bag_space;
    reg [15:0] temp_total;
    
    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            bags <= 16'd0;
            done <= 1'b0;
            day_cnt <= 8'd0;
            leftover <= 8'd0;
            current_garbage <= 8'd0;
            bags_needed <= 8'd0;
            bag_space <= 8'd0;
            temp_total <= 16'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        day_cnt <= 8'd0;
                        leftover <= 8'd0;
                        temp_total <= 16'd0;
                        next_state <= PROCESS;
                    end
                end
                
                PROCESS: begin
                    // Select current day garbage
                    case (day_cnt)
                        3'd0: current_garbage <= a_0;
                        3'd1: current_garbage <= a_1;
                        3'd2: current_garbage <= a_2;
                        3'd3: current_garbage <= a_3;
                        3'd4: current_garbage <= a_4;
                        3'd5: current_garbage <= a_5;
                        3'd6: current_garbage <= a_6;
                        3'd7: current_garbage <= a_7;
                        default: current_garbage <= 8'd0;
                    endcase
                    
                    // Process leftover from previous day
                    if (leftover != 8'd0) begin
                        // ceil(leftover/k) = (leftover+k-1)/k
                        bags_needed <= (leftover + k - 8'd1) / k;
                        temp_total <= temp_total + bags_needed;
                        
                        // Calculate space used for previous leftover
                        bag_space <= k * bags_needed - leftover;
                    end else begin
                        bags_needed <= 8'd0;
                        bag_space <= 8'd0;
                    end
                    
                    // Update current leftover
                    if (current_garbage <= bag_space) begin
                        leftover <= 8'd0;
                    end else begin
                        leftover <= current_garbage - bag_space;
                    end
                    
                    // Increment day counter
                    if (day_cnt < n - 8'd1) begin
                        day_cnt <= day_cnt + 8'd1;
                    end else begin
                        next_state <= FINISH;
                    end
                end
                
                FINISH: begin
                    // Dispose remaining leftover after last day
                    if (leftover != 8'd0) begin
                        bags_needed <= (leftover + k - 8'd1)/k;
                        temp_total <= temp_total + bags_needed;
                    end
                    bags <= temp_total;
                    next_state <= DONE_ST;
                end
                
                DONE_ST: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end
endmodule