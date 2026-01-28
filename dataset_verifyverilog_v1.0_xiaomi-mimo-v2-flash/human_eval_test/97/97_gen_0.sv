module UnitDigitProduct (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [7:0] a,
    input wire signed [7:0] b,
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [7:0] abs_a;
    reg [7:0] abs_b;
    reg [7:0] unit_a;
    reg [7:0] unit_b;
    
    // Helper signals for division
    wire [15:0] a_times_10;
    wire [15:0] b_times_10;
    wire [7:0] div_a;
    wire [7:0] div_b;
    wire [7:0] rem_a;
    wire [7:0] rem_b;
    
    // Compute abs values (two's complement)
    always @(*) begin
        abs_a = (a[7] == 1'b1) ? (~a + 8'd1) : a;
        abs_b = (b[7] == 1'b1) ? (~b + 8'd1) : b;
    end
    
    // Division by 10: abs_val - 10 * (abs_val / 10)
    // Using shift-add approximation for 10*quotient
    assign a_times_10 = {div_a, 3'd0} + {2'd0, div_a, 1'd0}; // *10
    assign b_times_10 = {div_b, 3'd0} + {2'd0, div_b, 1'd0}; // *10
    
    assign div_a = abs_a >= 8'd100 ? 8'd10 : 
                   abs_a >= 8'd90 ? 8'd9 : 
                   abs_a >= 8'd80 ? 8'd8 : 
                   abs_a >= 8'd70 ? 8'd7 : 
                   abs_a >= 8'd60 ? 8'd6 : 
                   abs_a >= 8'd50 ? 8'd5 : 
                   abs_a >= 8'd40 ? 8'd4 : 
                   abs_a >= 8'd30 ? 8'd3 : 
                   abs_a >= 8'd20 ? 8'd2 : 
                   abs_a >= 8'd10 ? 8'd1 : 8'd0;
                   
    assign div_b = abs_b >= 8'd100 ? 8'd10 : 
                   abs_b >= 8'd90 ? 8'd9 : 
                   abs_b >= 8'd80 ? 8'd8 : 
                   abs_b >= 8'd70 ? 8'd7 : 
                   abs_b >= 8'd60 ? 8'd6 : 
                   abs_b >= 8'd50 ? 8'd5 : 
                   abs_b >= 8'd40 ? 8'd4 : 
                   abs_b >= 8'd30 ? 8'd3 : 
                   abs_b >= 8'd20 ? 8'd2 : 
                   abs_b >= 8'd10 ? 8'd1 : 8'd0;
    
    assign rem_a = abs_a - a_times_10[7:0];
    assign rem_b = abs_b - b_times_10[7:0];
    
    // Sequential FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            unit_a <= 8'd0;
            unit_b <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE;
                        // Pre-calculate unit digits in same cycle
                        unit_a <= rem_a;
                        unit_b <= rem_b;
                    end
                end
                
                COMPUTE: begin
                    // Multiply unit digits (0-9 * 0-9 = 0-81)
                    result <= unit_a * unit_b;
                    state <= FINISH;
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