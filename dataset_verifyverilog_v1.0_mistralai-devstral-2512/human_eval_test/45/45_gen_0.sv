module TriangleArea(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [15:0] a,
    input wire signed [15:0] h,
    output reg signed [31:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH  = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd10;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Fixed-point multiplication: Q16.16 * Q16.16 = Q32.32
                    wire signed [31:0] a_ext = {{16{a[15]}}, a};
                    wire signed [31:0] h_ext = {{16{h[15]}}, h};
                    wire signed [63:0] product = a_ext * h_ext;
                    
                    // Divide by 2: shift right by 1 (Q32.32 >> 1 = Q32.31)
                    // Then shift right by 15 more to get Q16.16
                    result <= product[47:16];
                    
                    // Exit conditions
                    if (cycle_count >= MAX_CYCLES) begin
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