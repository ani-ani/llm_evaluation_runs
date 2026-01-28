module PythagoreanTriangleDetector(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] side_a,
    input wire [15:0] side_b,
    input wire [15:0] side_c,
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd50;

    // Input registers
    reg [15:0] a_reg, b_reg, c_reg;

    // Intermediate computation registers
    reg [31:0] a_sq, b_sq, c_sq;
    reg [31:0] ab_sum, ac_sum, bc_sum;
    reg [31:0] ab_diff, ac_diff, bc_diff;

    // Result computation
    reg ab_valid, ac_valid, bc_valid;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            a_reg <= 16'd0;
            b_reg <= 16'd0;
            c_reg <= 16'd0;
            a_sq <= 32'd0;
            b_sq <= 32'd0;
            c_sq <= 32'd0;
            ab_sum <= 32'd0;
            ac_sum <= 32'd0;
            bc_sum <= 32'd0;
            ab_diff <= 32'd0;
            ac_diff <= 32'd0;
            bc_diff <= 32'd0;
            ab_valid <= 1'b0;
            ac_valid <= 1'b0;
            bc_valid <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                        a_reg <= side_a;
                        b_reg <= side_b;
                        c_reg <= side_c;
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Compute squares
                    a_sq <= $signed(a_reg) * $signed(a_reg);
                    b_sq <= $signed(b_reg) * $signed(b_reg);
                    c_sq <= $signed(c_reg) * $signed(c_reg);
                    
                    // Compute sums (scaled to Q8.8)
                    ab_sum <= (a_sq >> 8) + (b_sq >> 8);
                    ac_sum <= (a_sq >> 8) + (c_sq >> 8);
                    bc_sum <= (b_sq >> 8) + (c_sq >> 8);
                    
                    // Compute differences
                    ab_diff <= ab_sum - (c_sq >> 8);
                    ac_diff <= ac_sum - (b_sq >> 8);
                    bc_diff <= bc_sum - (a_sq >> 8);
                    
                    // Check tolerance (±16 LSBs)
                    ab_valid <= (ab_diff >= -16 && ab_diff <= 16);
                    ac_valid <= (ac_diff >= -16 && ac_diff <= 16);
                    bc_valid <= (bc_diff >= -16 && bc_diff <= 16);
                    
                    // Exit conditions
                    if (cycle_count >= MAX_CYCLES || cycle_count >= 8'd30) begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    result <= ab_valid || ac_valid || bc_valid;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule