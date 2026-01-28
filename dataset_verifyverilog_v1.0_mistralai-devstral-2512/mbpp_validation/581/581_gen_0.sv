module pyramid_surface_area(
    input clk,
    input rst_n,
    input start,
    input signed [31:0] base_edge_q16,
    input signed [31:0] slant_height_q16,
    output reg signed [31:0] result_q16,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH  = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Intermediate registers for pipelined computation
    reg signed [63:0] term1_temp;
    reg signed [63:0] term2_temp;
    reg signed [31:0] term1_q16;
    reg signed [31:0] term2_q16;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_q16 <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            term1_temp <= 64'd0;
            term2_temp <= 64'd0;
            term1_q16 <= 32'd0;
            term2_q16 <= 32'd0;
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
                    
                    // Compute term1 = 2 * base_edge * slant_height (Q32.32 -> Q16.16)
                    term1_temp <= {base_edge_q16, 32'd0} + {base_edge_q16, 32'd0};
                    term1_temp <= term1_temp * {slant_height_q16, 32'd0};
                    term1_q16 <= term1_temp[63:32];  // Take upper 32 bits (Q16.16)
                    
                    // Compute term2 = base_edge * base_edge (Q32.32 -> Q16.16)
                    term2_temp <= {base_edge_q16, 32'd0} * {base_edge_q16, 32'd0};
                    term2_q16 <= term2_temp[63:32];  // Take upper 32 bits (Q16.16)
                    
                    // Compute final result = term1 + term2 (Q16.16)
                    result_q16 <= term1_q16 + term2_q16;
                    
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