module area_calculator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] a,
    input wire [31:0] b,
    input wire [31:0] c,
    output reg [31:0] area,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE_SQUARES = 2'd1;
    localparam [1:0] COMPUTE_S = 2'd2;
    localparam [1:0] COMPUTE_D = 2'd3;
    localparam [1:0] CHECK_D = 2'd4;
    localparam [1:0] COMPUTE_SQRT = 2'd5;
    localparam [1:0] COMPUTE_T = 2'd6;
    localparam [1:0] CHECK_T = 2'd7;
    localparam [1:0] COMPUTE_AREA = 2'd8;
    localparam [1:0] DONE_STATE = 2'd9;

    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Intermediate registers
    reg [31:0] a2, b2, c2;
    reg [63:0] a2_temp, b2_temp, c2_temp;
    reg [63:0] S_temp;
    reg [31:0] S;
    reg [63:0] D_temp;
    reg [31:0] D;
    reg [31:0] sqrt_D;
    reg [31:0] t;
    reg [63:0] lower_bound_temp;
    reg [31:0] lower_bound;
    reg [63:0] area_temp;

    // Square root computation registers
    reg [31:0] sqrt_x;
    reg [31:0] sqrt_y;
    reg [31:0] sqrt_z;
    reg [31:0] sqrt_result;
    reg [4:0] sqrt_iter;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            area <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            a2 <= 32'd0;
            b2 <= 32'd0;
            c2 <= 32'd0;
            a2_temp <= 64'd0;
            b2_temp <= 64'd0;
            c2_temp <= 64'd0;
            S_temp <= 64'd0;
            S <= 32'd0;
            D_temp <= 64'd0;
            D <= 32'd0;
            sqrt_D <= 32'd0;
            t <= 32'd0;
            lower_bound_temp <= 64'd0;
            lower_bound <= 32'd0;
            area_temp <= 64'd0;
            sqrt_x <= 32'd0;
            sqrt_y <= 32'd0;
            sqrt_z <= 32'd0;
            sqrt_result <= 32'd0;
            sqrt_iter <= 5'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE_SQUARES;
                    end
                end

                COMPUTE_SQUARES: begin
                    cycle_count <= cycle_count + 8'd1;
                    a2_temp <= {32'd0, a} * {32'd0, a};
                    b2_temp <= {32'd0, b} * {32'd0, b};
                    c2_temp <= {32'd0, c} * {32'd0, c};
                    a2 <= a2_temp[47:16];
                    b2 <= b2_temp[47:16];
                    c2 <= c2_temp[47:16];
                    state <= COMPUTE_S;
                end

                COMPUTE_S: begin
                    cycle_count <= cycle_count + 8'd1;
                    S_temp <= {32'd0, a2} + {32'd0, b2} + {32'd0, c2};
                    S <= S_temp[47:16];
                    state <= COMPUTE_D;
                end

                COMPUTE_D: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Compute 2*(a2*b2 + a2*c2 + b2*c2)
                    reg [63:0] term1, term2, term3;
                    term1 <= ({32'd0, a2} * {32'd0, b2})[47:16];
                    term2 <= ({32'd0, a2} * {32'd0, c2})[47:16];
                    term3 <= ({32'd0, b2} * {32'd0, c2})[47:16];
                    reg [63:0] sum_terms;
                    sum_terms <= term1 + term2 + term3;
                    reg [63:0] two_sum_terms;
                    two_sum_terms <= sum_terms << 1;

                    // Compute (a2^2 + b2^2 + c2^2)
                    reg [63:0] a2_sq, b2_sq, c2_sq;
                    a2_sq <= ({32'd0, a2} * {32'd0, a2})[47:16];
                    b2_sq <= ({32'd0, b2} * {32'd0, b2})[47:16];
                    c2_sq <= ({32'd0, c2} * {32'd0, c2})[47:16];
                    reg [63:0] sum_squares;
                    sum_squares <= a2_sq + b2_sq + c2_sq;

                    // Compute D = 3 * (2*sum_terms - sum_squares)
                    reg [63:0] diff;
                    diff <= two_sum_terms - sum_squares;
                    D_temp <= diff * 3;
                    D <= D_temp[47:16];
                    state <= CHECK_D;
                end

                CHECK_D: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (D[31] || (D == 32'd0)) begin
                        area <= 32'hFFFFFFFF;
                        state <= DONE_STATE;
                    end else begin
                        sqrt_x <= D;
                        sqrt_y <= 32'd0;
                        sqrt_z <= 32'd0;
                        sqrt_iter <= 5'd0;
                        state <= COMPUTE_SQRT;
                    end
                end

                COMPUTE_SQRT: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (sqrt_iter < 5'd16) begin
                        sqrt_z <= sqrt_y + 1'b1;
                        sqrt_y <= sqrt_y >> 1;
                        if (sqrt_x >= sqrt_z) begin
                            sqrt_x <= sqrt_x - sqrt_z;
                            sqrt_result <= sqrt_result + sqrt_y;
                        end
                        sqrt_iter <= sqrt_iter + 5'd1;
                    end else begin
                        sqrt_D <= sqrt_result;
                        state <= COMPUTE_T;
                    end
                end

                COMPUTE_T: begin
                    cycle_count <= cycle_count + 8'd1;
                    reg [63:0] t_temp;
                    t_temp <= {32'd0, S} + {32'd0, sqrt_D};
                    t <= t_temp[47:16];
                    state <= CHECK_T;
                end

                CHECK_T: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Compute |a2 - b2|
                    reg [32:0] abs_ab;
                    if (a2 > b2) begin
                        abs_ab <= a2 - b2;
                    end else begin
                        abs_ab <= b2 - a2;
                    end

                    // Compute 2*c2 - a2 - b2
                    reg [32:0] term1;
                    term1 <= (c2 << 1) - a2 - b2;

                    // Compute 2*b2 - a2 - c2
                    reg [32:0] term2;
                    term2 <= (b2 << 1) - a2 - c2;

                    // Compute 2*a2 - b2 - c2
                    reg [32:0] term3;
                    term3 <= (a2 << 1) - b2 - c2;

                    // Find max
                    reg [32:0] max1, max2;
                    if (abs_ab > term1) begin
                        max1 <= abs_ab;
                    end else begin
                        max1 <= term1;
                    end

                    if (term2 > term3) begin
                        max2 <= term2;
                    end else begin
                        max2 <= term3;
                    end

                    if (max1 > max2) begin
                        lower_bound <= max1;
                    end else begin
                        lower_bound <= max2;
                    end

                    if (t < lower_bound) begin
                        area <= 32'hFFFFFFFF;
                        state <= DONE_STATE;
                    end else begin
                        state <= COMPUTE_AREA;
                    end
                end

                COMPUTE_AREA: begin
                    cycle_count <= cycle_count + 8'd1;
                    area_temp <= {32'd0, 32'd28378} * {32'd0, t};
                    area <= area_temp[47:16];
                    state <= DONE_STATE;
                end

                DONE_STATE: begin
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