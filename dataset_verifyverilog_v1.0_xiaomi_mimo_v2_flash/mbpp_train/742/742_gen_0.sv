module tetrahedron_area (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] side,  // Q8.8 fixed-point format (8 integer, 8 fractional bits)
    output reg [31:0] result, // Q16.16 fixed-point output
    output reg done
);

    // Constants: sqrt(3) in Q16.16 format = 1.7320508075688772 * 65536 = 113513
    localparam [31:0] SQRT3_FIXED = 32'd113513;  // Q16.16 representation of sqrt(3)
    
    // State machine states
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] COMPLETE = 2'd2;
    
    reg [1:0] state;
    
    // Internal registers
    reg [31:0] side_sq;      // side^2 in Q16.16
    reg [31:0] product;      // sqrt(3) * side^2 in Q16.16
    reg [7:0] cycle_count;   // Computation cycle counter
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 32'd0;
            side_sq <= 32'd0;
            product <= 32'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Convert side to Q16.16 (multiply by 256) and square
                        // side in Q8.8 -> Q16.16: shift left by 8
                        // side_sq = (side * side) << 8
                        side_sq <= ({16'd0, side} * {16'd0, side}) << 8;
                        state <= COMPUTE;
                        cycle_count <= 8'd0;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Single cycle multiplication (combinational in hardware)
                    // result = sqrt(3) * side^2
                    // Both are Q16.16, result Q16.16
                    // Multiply then shift right by 16 to keep Q16.16 format
                    product <= (SQRT3_FIXED * side_sq) >> 16;
                    
                    // Move to complete state
                    state <= COMPLETE;
                end
                
                COMPLETE: begin
                    result <= product;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule