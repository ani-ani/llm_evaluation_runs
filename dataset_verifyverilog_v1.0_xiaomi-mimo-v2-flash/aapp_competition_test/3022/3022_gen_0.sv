module cookie_distribution(
    input clk,
    input rst_n,
    input start,
    input [9:0] N,
    input [9:0] A,
    input [9:0] B,
    input [9:0] C,
    output reg [21:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CALC = 2'd1;
    localparam [1:0] DONE = 2'd2;

    reg [1:0] state, next_state;
    
    // Internal registers
    reg [21:0] sum_reg;
    reg [9:0] max_val_reg;
    reg [11:0] rest_reg;
    reg [11:0] threshold_reg;
    reg max_gt_threshold;
    reg [21:0] result_next;
    
    // Combinational logic for max calculation
    wire [9:0] max_ab;
    wire [9:0] max_abc;
    assign max_ab = (A > B) ? A : B;
    assign max_abc = (max_ab > C) ? max_ab : C;
    
    // State register and reset
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 22'd0;
            done <= 1'b0;
            sum_reg <= 22'd0;
            max_val_reg <= 10'd0;
            rest_reg <= 12'd0;
            threshold_reg <= 12'd0;
            max_gt_threshold <= 1'b0;
        end else begin
            state <= next_state;
            
            // Register updates for CALC state
            if (state == IDLE && start) begin
                sum_reg <= {12'd0, A} + {12'd0, B} + {12'd0, C};
                max_val_reg <= max_abc;
            end
            
            if (state == CALC) begin
                rest_reg <= sum_reg[11:0] - {2'd0, max_val_reg};
                threshold_reg <= (sum_reg[11:0] - {2'd0, max_val_reg}) + {2'd0, N};
                
                // Perform comparison and calculation for next state
                // Compare max_val_reg (10-bit) with threshold_reg (12-bit)
                // Since max_val_reg is 10-bit, and threshold is at least N (10-bit),
                // we can safely compare extended values
                if (max_val_reg > threshold_reg[9:0]) begin
                    max_gt_threshold <= 1'b1;
                    // Result = Rest * 2 + N
                    // Rest is 12-bit, result needs 22-bit
                    result_next <= ({10'd0, rest_reg} << 1) + {12'd0, N};
                end else begin
                    max_gt_threshold <= 1'b0;
                    result_next <= sum_reg;
                end
            end
            
            if (state == DONE) begin
                result <= result_next;
                done <= 1'b1;
            end else begin
                done <= 1'b0;
            end
        end
    end
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = CALC;
                else
                    next_state = IDLE;
            end
            CALC: begin
                next_state = DONE;
            end
            DONE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

endmodule