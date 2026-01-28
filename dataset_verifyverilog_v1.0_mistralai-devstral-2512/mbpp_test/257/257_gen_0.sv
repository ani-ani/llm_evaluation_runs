module swap_module(
    input clk,
    input rst_n,
    input start,
    input [7:0] a,
    input [7:0] b,
    output reg [7:0] result_a,
    output reg [7:0] result_b,
    output reg done
);
    
    // State declarations
    localparam [1:0] IDLE     = 2'd0;
    localparam [1:0] PROCESS  = 2'd1;
    localparam [1:0] COMPLETE = 2'd2;
    
    reg [1:0] state;
    reg [7:0] captured_a;
    reg [7:0] captured_b;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_a <= 8'd0;
            result_b <= 8'd0;
            done <= 1'b0;
            captured_a <= 8'd0;
            captured_b <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start && !done) begin
                        captured_a <= a;
                        captured_b <= b;
                        state <= PROCESS;
                    end
                end
                
                PROCESS: begin
                    result_a <= captured_b;
                    result_b <= captured_a;
                    state <= COMPLETE;
                end
                
                COMPLETE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule