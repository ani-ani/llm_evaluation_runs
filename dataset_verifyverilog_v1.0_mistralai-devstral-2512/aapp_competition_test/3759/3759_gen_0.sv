module ChubbyYang(
    input clk,
    input rst_n,
    input start,
    input [25:0] n_in,
    output reg [31:0] result,
    output reg done
);
    
    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH  = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd10;
    
    // Fixed-point sqrt(2) in Q32.32 format
    localparam [63:0] sqrt2_fixed = 64'h16A09E667F3BCD;
    
    // Intermediate multiplication result
    reg [63:0] mult_result;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            mult_result <= 64'd0;
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
                    
                    // Special case: n_in == 0
                    if (n_in == 26'd0) begin
                        result <= 32'd1;
                        state <= FINISH;
                    end else begin
                        // Multiply n_in by sqrt2_fixed (32.32 format)
                        mult_result <= {32'd0, n_in} * sqrt2_fixed;
                        
                        // Take upper 32 bits (integer part) and multiply by 4
                        result <= (mult_result[63:32] << 2'b10);
                        
                        // Exit conditions
                        if (cycle_count >= MAX_CYCLES) begin
                            state <= FINISH;
                        end else begin
                            state <= FINISH;
                        end
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