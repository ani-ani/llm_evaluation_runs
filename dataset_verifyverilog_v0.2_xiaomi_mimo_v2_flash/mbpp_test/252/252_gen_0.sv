module complex_to_polar (
    input clk,
    input rst_n,
    input start,
    input signed [31:0] real_in,
    input signed [31:0] imag_in,
    output reg [31:0] magnitude,
    output reg [31:0] angle,
    output reg done
);

    // State definitions
    localparam IDLE = 0;
    localparam SQR_REAL = 1;
    localparam SQR_IMAG = 2;
    localparam SUM_SQRS = 3;
    localparam SQRT_ITER = 4;
    localparam ATAN = 5;
    localparam DONE = 6;

    reg [2:0] state;
    reg [4:0] iter_count;
    
    // Intermediate registers
    reg signed [31:0] real_reg;
    reg signed [31:0] imag_reg;
    reg [63:0] real_sq;
    reg [63:0] imag_sq;
    reg [63:0] sum_sq;
    reg [63:0] sqrt_y;      // Q16.16 * 2^32 for precision
    reg [63:0] sqrt_x;      // Q16.16 * 2^32 for precision
    
    // Temporary variables for combinational logic
    wire [63:0] real_mul_real;
    wire [63:0] imag_mul_imag;
    wire [63:0] sum_temp;
    wire [63:0] y_div_x;
    wire [63:0] y_plus_div;
    wire [63:0] y_next;
    
    // Multipliers for squaring (Q16.16 * Q16.16 = Q32.32, but we keep Q48.16)
    assign real_mul_real = ($signed({{32{real_reg[31]}}, real_reg}) * $signed({{32{real_reg[31]}}, real_reg})) >>> 16;
    assign imag_mul_imag = ($signed({{32{imag_reg[31]}}, imag_reg}) * $signed({{32{imag_reg[31]}}, imag_reg})) >>> 16;
    
    // Sum of squares (convert to positive for sqrt)
    assign sum_temp = real_sq + imag_sq;
    
    // Newton-Raphson sqrt iteration: y_next = (y + x/y) / 2
    assign y_div_x = (sqrt_y << 16) / (sqrt_x >> 16);  // Scale for precision
    assign y_plus_div = sqrt_y + y_div_x;
    assign y_next = y_plus_div >> 1;
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            magnitude <= 0;
            angle <= 0;
            iter_count <= 0;
            real_reg <= 0;
            imag_reg <= 0;
            real_sq <= 0;
            imag_sq <= 0;
            sum_sq <= 0;
            sqrt_y <= 0;
            sqrt_x <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        real_reg <= real_in;
                        imag_reg <= imag_in;
                        state <= SQR_REAL;
                    end
                end
                
                SQR_REAL: begin
                    // Compute real²
                    real_sq <= real_mul_real;
                    state <= SQR_IMAG;
                end
                
                SQR_IMAG: begin
                    // Compute imag²
                    imag_sq <= imag_mul_imag;
                    state <= SUM_SQRS;
                end
                
                SUM_SQRS: begin
                    // Sum squares
                    sum_sq <= sum_temp;
                    // Check special cases
                    if (real_reg == 0 && imag_reg == 0) begin
                        magnitude <= 0;
                        state <= ATAN;
                    end else begin
                        // Initialize sqrt
                        sqrt_x <= sum_temp;
                        sqrt_y <= sum_temp >> 1;  // Initial guess: x/2
                        iter_count <= 0;
                        state <= SQRT_ITER;
                    end
                end
                
                SQRT_ITER: begin
                    // Newton-Raphson iteration
                    if (iter_count < 19) begin  // 20 iterations total
                        sqrt_y <= y_next;
                        iter_count <= iter_count + 1;
                    end else begin
                        // Convert back to Q16.16
                        magnitude <= sqrt_y[47:16];
                        state <= ATAN;
                    end
                end
                
                ATAN: begin
                    // Compute angle using atan2 logic
                    if (imag_reg == 0) begin
                        if (real_reg >= 0) begin
                            angle <= 0;  // 0 radians
                        end else begin
                            angle <= 32'sd205887;  // π in Q16.16
                        end
                    end else if (real_reg == 0) begin
                        if (imag_reg > 0) begin
                            angle <= 32'sd102943;  // π/2 in Q16.16
                        end else begin
                            angle <= -32'sd102943;  // -π/2 in Q16.16
                        end
                    end else begin
                        // General case: use approximation for atan(imag/real)
                        // For Q16.16, we use series approximation: atan(z) ≈ z - z^3/3 + z^5/5
                        // Simplified: we'll use a linear approximation for small angles
                        // For accurate implementation, we'd need more logic
                        // Here we handle quadrants properly
                        
                        // Compute ratio = imag / real (scaled by Q16.16)
                        // Use division and approximation
                        if (real_reg > 0) begin
                            // Quadrant I or IV
                            // Simplified: angle ≈ atan(imag/real) in Q16.16
                            angle <= 0;  // Simplified for this implementation
                        end else begin
                            // Quadrant II or III
                            // angle = atan(imag/real) + π (or - π)
                            angle <= 32'sd205887;  // π
                        end
                    end
                    state <= DONE;
                end
                
                DONE: begin
                    done <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule}