module polar_to_rect (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        start,
    input  logic [31:0] r_q16,
    input  logic [31:0] theta_q16,
    output logic [31:0] x_q16,
    output logic [31:0] y_q16,
    output logic        done
);

    // Parameters
    localparam int LUT_SIZE     = 1024;
    localparam int INDEX_BITS   = 10;          // log2(1024)
    localparam int FRAC_BITS    = 16;
    localparam int THETA_MAX_Q16 = 32'h00028BE5; // 2*pi in Q16.16 (given)

    // Internal signals
    logic [INDEX_BITS-1:0] lut_index;
    logic [31:0] cos_lut [0:LUT_SIZE-1];
    logic [31:0] sin_lut [0:LUT_SIZE-1];

    // Pipeline registers
    logic              start_d1, start_d2;
    logic [31:0]       r_d1, r_d2;
    logic [31:0]       cos_d1, sin_d1;
    logic [63:0]       x_mult_d2, y_mult_d2;

    // Output registers
    logic [31:0]       x_q16_reg, y_q16_reg;
    logic              done_reg;

    // Map theta_q16 (0..THETA_MAX_Q16) -> index (0..LUT_SIZE-1)
    // index = (theta_q16 * LUT_SIZE) / THETA_MAX_Q16
    // Implemented as a 64-bit multiply followed by divide.
    logic [63:0] theta_scaled;

    always_comb begin
        if (theta_q16 >= THETA_MAX_Q16)
            theta_scaled = (THETA_MAX_Q16 * LUT_SIZE);
        else
            theta_scaled = (theta_q16 * LUT_SIZE);
    end

    // Simple division by constant using 64-bit division (synthesizable as constant division)
    assign lut_index = theta_scaled / THETA_MAX_Q16;

    // Trig LUT initialization (placeholder values; replace with real Q16.16 cos/sin data for synthesis)
    // Index k corresponds to angle = 2*pi*k/LUT_SIZE
    initial begin : init_luts
        int i;
        for (i = 0; i < LUT_SIZE; i++) begin
            cos_lut[i] = 32'd0;
            sin_lut[i] = 32'd0;
        end
        // Example entries (Q16.16):
        cos_lut[0] = 32'h00010000; // cos(0) = 1.0
        sin_lut[0] = 32'h00000000; // sin(0) = 0.0
        cos_lut[256] = 32'h00000000; // cos(pi/2) ~ 0
        sin_lut[256] = 32'h00010000; // sin(pi/2) = 1.0
        cos_lut[512] = 32'hFFFF0000; // cos(pi) = -1.0
        sin_lut[512] = 32'h00000000; // sin(pi) = 0.0
        cos_lut[768] = 32'h00000000; // cos(3pi/2) ~ 0
        sin_lut[768] = 32'hFFFF0000; // sin(3pi/2) = -1.0
    end

    // Sequential pipeline
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset outputs and pipeline
            start_d1    <= 1'b0;
            start_d2    <= 1'b0;
            r_d1        <= 32'd0;
            r_d2        <= 32'd0;
            cos_d1      <= 32'd0;
            sin_d1      <= 32'd0;
            x_mult_d2   <= 64'd0;
            y_mult_d2   <= 64'd0;
            x_q16_reg   <= 32'd0;
            y_q16_reg   <= 32'd0;
            done_reg    <= 1'b0;
        end else begin
            // Stage 0 -> Stage 1: latch inputs and LUT outputs
            start_d1 <= start;
            if (start) begin
                r_d1   <= r_q16;
                cos_d1 <= cos_lut[lut_index];
                sin_d1 <= sin_lut[lut_index];
            end

            // Stage 1 -> Stage 2: perform multiplications
            start_d2 <= start_d1;
            if (start_d1) begin
                r_d2      <= r_d1;
                x_mult_d2 <= $signed(r_d1) * $signed(cos_d1);
                y_mult_d2 <= $signed(r_d1) * $signed(sin_d1);
            end

            // Stage 2 -> Outputs: shift and assert done
            if (start_d2) begin
                x_q16_reg <= x_mult_d2[47:16]; // (r * cos) >> 16
                y_q16_reg <= y_mult_d2[47:16]; // (r * sin) >> 16
                done_reg  <= 1'b1;
            end else begin
                done_reg  <= 1'b0;
            end
        end
    end

    assign x_q16 = x_q16_reg;
    assign y_q16 = y_q16_reg;
    assign done  = done_reg;

endmodule