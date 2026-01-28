module arnar_location_calculator (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [63:0] params,
    output reg [31:0] result,
    output reg done
);

// Constants (Q16.16 format)
localparam [31:0] PI = 32'd205887;
localparam [31:0] E = 32'd178145;
localparam [31:0] GAMMA_HALF = 32'd116077;
localparam [31:0] ONE = 32'd65536;
localparam [31:0] ZERO = 32'd0;

// FSM States
localparam [2:0] IDLE = 3'd0;
localparam [2:0] LOAD_PARAMS = 3'd1;
localparam [2:0] COMPUTE_COEFF = 3'd2;
localparam [2:0] BUILD_POLY = 3'd3;
localparam [2:0] FINAL_EVAL = 3'd4;
localparam [2:0] DONE_STATE = 3'd5;

// Input registers
reg [9:0] r_reg;
reg [9:0] s_reg;
reg [9:0] n_reg;
reg [9:0] k_reg;
reg [9:0] l_reg;

// State registers
reg [2:0] state;
reg [2:0] next_state;
reg [7:0] counter;
reg [7:0] cycle_counter;

// Coefficient memory (0..25)
reg [31:0] coeff [0:25];

// Polynomial memory (0..30)
reg [31:0] poly [0:30];

// Temporary registers for computation
reg [31:0] temp_reg;
reg [31:0] temp_reg2;
reg [31:0] temp_reg3;
reg [31:0] l_squared;
reg [31:0] pi_e_product;
reg [31:0] l_plus_one;

// Multiplication/Division flags
reg do_mult;
reg do_div;
reg do_div2;
reg mult_done;
reg div_done;
reg div2_done;

// Iteration counters
reg [3:0] iter_count;

// Result register for final output
reg [31:0] result_reg;
reg done_reg;

// Integer for loops
integer i;

// For division (Newton-Raphson)
reg [63:0] div_a;
reg [31:0] div_b;
reg [31:0] div_xn;
reg [31:0] div_xn_next;

// For multiplication
reg [63:0] mult_a;
reg [63:0] mult_b;
reg [63:0] mult_result;

// State transition and reset
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        result <= 32'd0;
        done <= 1'b0;
        counter <= 8'd0;
        cycle_counter <= 8'd0;
        r_reg <= 10'd0;
        s_reg <= 10'd0;
        n_reg <= 10'd0;
        k_reg <= 10'd0;
        l_reg <= 10'd0;
        temp_reg <= 32'd0;
        temp_reg2 <= 32'd0;
        temp_reg3 <= 32'd0;
        l_squared <= 32'd0;
        pi_e_product <= 32'd0;
        l_plus_one <= 32'd0;
        do_mult <= 1'b0;
        do_div <= 1'b0;
        do_div2 <= 1'b0;
        mult_done <= 1'b0;
        div_done <= 1'b0;
        div2_done <= 1'b0;
        iter_count <= 4'd0;
        div_xn <= 32'd0;
        div_xn_next <= 32'd0;
        for (i = 0; i < 26; i = i + 1) begin
            coeff[i] <= 32'd0;
        end
        for (i = 0; i < 31; i = i + 1) begin
            poly[i] <= 32'd0;
        end
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                counter <= 8'd0;
                cycle_counter <= 8'd0;
                do_mult <= 1'b0;
                do_div <= 1'b0;
                do_div2 <= 1'b0;
                mult_done <= 1'b0;
                div_done <= 1'b0;
                div2_done <= 1'b0;
                if (start) begin
                    state <= LOAD_PARAMS;
                end
            end
            
            LOAD_PARAMS: begin
                r_reg <= params[9:0];
                s_reg <= params[19:10];
                n_reg <= params[29:20];
                k_reg <= params[39:30];
                l_reg <= params[49:40];
                // Initialize coefficient array
                for (i = 0; i < 26; i = i + 1) begin
                    coeff[i] <= 32'd0;
                end
                // Set coeff[0] = c = Gamma(0) = 1.0
                coeff[0] <= ONE;
                counter <= 8'd0;
                state <= COMPUTE_COEFF;
            end
            
            COMPUTE_COEFF: begin
                // Coefficients are already computed (all zero except coeff[0]=1)
                // Just delay to stay in pipeline
                counter <= counter + 8'd1;
                if (counter >= 8'd2) begin
                    counter <= 8'd0;
                    // Initialize poly array
                    for (i = 0; i < 31; i = i + 1) begin
                        poly[i] <= 32'd0;
                    end
                    poly[0] <= coeff[0]; // P_0 = c = 1
                    state <= BUILD_POLY;
                end
            end
            
            BUILD_POLY: begin
                // Build P_n from P_{n-1}: P_n(x) = sum P_{n-1}(i) * x^i
                // Since P_0 = c (constant), all subsequent polynomials are just c
                // We need to build P_s
                // This is a simplification - we just need poly[0] = c = 1
                counter <= counter + 8'd1;
                if (counter >= s_reg[7:0]) begin
                    // poly[0] now holds c (which is 1)
                    counter <= 8'd0;
                    // Compute l^2
                    mult_a <= {22'd0, l_reg, 10'd0}; // l in Q16.16
                    mult_b <= {22'd0, l_reg, 10'd0};
                    do_mult <= 1'b1;
                    state <= FINAL_EVAL;
                end
            end
            
            FINAL_EVAL: begin
                // Multiplication pipeline
                if (do_mult && !mult_done) begin
                    mult_result <= mult_a[47:16] * mult_b[47:16]; // Q32.32 -> Q16.16
                    mult_done <= 1'b1;
                end else if (mult_done && !do_div) begin
                    l_squared <= mult_result[63:32]; // Q16.16
                    mult_done <= 1'b0;
                    do_mult <= 1'b0;
                    // Start second computation: 1/(pi*e)
                    mult_a <= PI;
                    mult_b <= E;
                    do_mult <= 1'b1;
                end else if (mult_done && do_div) begin
                    // Division 1/(pi*e)
                    if (!div_done) begin
                        // Newton-Raphson: x_{n+1} = x_n * (2 - a*x_n)
                        if (iter_count == 4'd0) begin
                            // Initial guess: 1/8 (approximation)
                            div_xn <= 32'd8192; // 1/8 in Q16.16
                            iter_count <= 4'd1;
                        end else begin
                            // x_{n+1} = x_n * (2 - a*x_n)
                            // temp = a * x_n
                            temp_reg <= mult_a * div_xn[31:16]; // Q32.32
                            // temp = 2 - temp
                            // Need to compute 2*ONE - temp[63:32]
                            temp_reg2 <= (32'd131072 - temp_reg[63:32]);
                            // x_{n+1} = x_n * temp
                            temp_reg3 <= div_xn * temp_reg2[31:16];
                            div_xn_next <= temp_reg3[63:32];
                            iter_count <= iter_count + 4'd1;
                            if (iter_count >= 4'd10) begin
                                div_xn <= div_xn_next;
                                div_done <= 1'b1;
                                iter_count <= 4'd0;
                            end else begin
                                div_xn <= div_xn_next;
                            end
                        end
                    end else if (div_done && !mult_done) begin
                        // Got 1/(pi*e) in div_xn
                        temp_reg2 <= div_xn;
                        mult_done <= 1'b0;
                        do_mult <= 1'b0;
                        do_div <= 1'b0;
                        // Compute l^2 * inv(pi*e)
                        mult_a <= l_squared;
                        mult_b <= div_xn;
                        do_mult <= 1'b1;
                    end else if (mult_done && !do_div2) begin
                        temp_reg3 <= mult_result[63:32]; // Q16.16
                        mult_done <= 1'b0;
                        do_mult <= 1'b0;
                        // Compute 1/(l+1)
                        // l+1 in Q16.16
                        l_plus_one <= {22'd0, l_reg, 10'd0} + ONE;
                        do_div2 <= 1'b1;
                    end else if (do_div2 && !div2_done) begin
                        if (iter_count == 4'd0) begin
                            div_xn <= 32'd32768; // 1/2
                            iter_count <= 4'd1;
                        end else begin
                            temp_reg <= l_plus_one * div_xn[31:16];
                            temp_reg2 <= 32'd131072 - temp_reg[63:32];
                            temp_reg3 <= div_xn * temp_reg2[31:16];
                            div_xn_next <= temp_reg3[63:32];
                            iter_count <= iter_count + 4'd1;
                            if (iter_count >= 4'd10) begin
                                div_xn <= div_xn_next;
                                div2_done <= 1'b1;
                                iter_count <= 4'd0;
                            end else begin
                                div_xn <= div_xn_next;
                            end
                        end
                    end else if (div2_done) begin
                        // Final addition
                        result_reg <= temp_reg3 + div_xn_next;
                        state <= DONE_STATE;
                        div2_done <= 1'b0;
                    end
                end
            end
            
            DONE_STATE: begin
                done <= 1'b1;
                result <= result_reg;
                state <= IDLE;
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule