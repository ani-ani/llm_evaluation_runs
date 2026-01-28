module MaxAbsDiff(
    input clk,
    input rst_n,
    input start,
    input [127:0] pairs_in,
    input [3:0] valid_pairs,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] CALC    = 3'd1;
    localparam [2:0] UPDATE  = 3'd2;
    localparam [2:0] DONE    = 3'd3;
    
    reg [2:0] state, next_state;
    reg [7:0] current_diff;
    reg [15:0] max_diff;
    reg [3:0] pair_counter;
    reg [7:0] pair_a, pair_b;
    reg [7:0] abs_diff;
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            max_diff <= 16'd0;
            pair_counter <= 4'd0;
            current_diff <= 8'd0;
            pair_a <= 8'd0;
            pair_b <= 8'd0;
            abs_diff <= 8'd0;
        end else begin
            state <= next_state;
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CALC;
                    pair_counter = 4'd0;
                    max_diff = 16'd0;
                end
            end
            
            CALC: begin
                if (pair_counter < valid_pairs - 4'd1) begin
                    next_state = CALC;
                end else begin
                    next_state = UPDATE;
                end
            end
            
            UPDATE: begin
                next_state = DONE;
            end
            
            DONE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Pair extraction and difference calculation
    always @(*) begin
        case (state)
            CALC: begin
                pair_a = pairs_in[(pair_counter * 8'd16) + 8'd7 : (pair_counter * 8'd16)];
                pair_b = pairs_in[(pair_counter * 8'd16) + 8'd15 : (pair_counter * 8'd16) + 8'd8];
                
                // Absolute difference calculation
                if (pair_a > pair_b) begin
                    abs_diff = pair_a - pair_b;
                end else begin
                    abs_diff = pair_b - pair_a;
                end
                
                current_diff = abs_diff;
            end
            
            default: begin
                current_diff = 8'd0;
                abs_diff = 8'd0;
            end
        endcase
    end
    
    // Max difference update
    always @(*) begin
        case (state)
            UPDATE: begin
                if (current_diff > max_diff[7:0]) begin
                    max_diff = {8'd0, current_diff};
                end
            end
            
            default: begin
                max_diff = max_diff;
            end
        endcase
    end
    
    // Output logic
    always @(*) begin
        result = 16'd0;
        done = 1'b0;
        
        case (state)
            CALC: begin
                result = max_diff;
            end
            
            UPDATE: begin
                result = max_diff;
            end
            
            DONE: begin
                result = max_diff;
                done = 1'b1;
            end
            
            default: begin
                result = 16'd0;
                done = 1'b0;
            end
        endcase
    end
    
    // Pair counter increment
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pair_counter <= 4'd0;
        end else begin
            if (state == CALC && next_state == CALC) begin
                pair_counter <= pair_counter + 4'd1;
            end
        end
    end

endmodule