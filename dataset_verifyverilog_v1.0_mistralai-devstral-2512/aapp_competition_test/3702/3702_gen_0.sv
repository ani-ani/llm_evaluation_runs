module FibonacciSubstringSearch(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [19:0] n,
    input wire [19:0] a,
    input wire [19:0] d,
    output reg [63:0] b,
    output reg [63:0] e,
    output reg valid
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_U = 3'd1;
    localparam [2:0] COMPUTE_V = 3'd2;
    localparam [2:0] COMPUTE_B = 3'd3;
    localparam [2:0] COMPUTE_E = 3'd4;
    localparam [2:0] FINISH = 3'd5;

    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd1000;

    // Precomputed constants
    localparam [33:0] N = 34'd12000000000;
    localparam [28:0] MULTIPLIER = 29'd368131125;
    localparam [29:0] MOD = 30'd1000000000;

    // Intermediate values
    reg [29:0] u;
    reg [29:0] v;

    // Iterative multiplication registers
    reg [19:0] a_reg;
    reg [19:0] d_reg;
    reg [28:0] multiplier_reg;
    reg [29:0] mod_reg;
    reg [29:0] product_u;
    reg [29:0] product_v;
    reg [29:0] remainder_u;
    reg [29:0] remainder_v;
    reg [5:0] mult_counter;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 8'd0;
            u <= 30'd0;
            v <= 30'd0;
            a_reg <= 20'd0;
            d_reg <= 20'd0;
            multiplier_reg <= 29'd0;
            mod_reg <= 30'd0;
            product_u <= 30'd0;
            product_v <= 30'd0;
            remainder_u <= 30'd0;
            remainder_v <= 30'd0;
            mult_counter <= 6'd0;
            b <= 64'd0;
            e <= 64'd0;
            valid <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    valid <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE_U;
                        a_reg <= a;
                        multiplier_reg <= MULTIPLIER;
                        mod_reg <= MOD;
                        product_u <= 30'd0;
                        remainder_u <= 30'd0;
                        mult_counter <= 6'd0;
                    end
                end

                COMPUTE_U: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (mult_counter < 6'd20) begin
                        if (a_reg[0]) begin
                            product_u <= product_u + multiplier_reg;
                        end
                        a_reg <= a_reg >> 1;
                        multiplier_reg <= multiplier_reg << 1;
                        mult_counter <= mult_counter + 6'd1;
                    end else begin
                        remainder_u <= product_u % mod_reg;
                        u <= remainder_u;
                        state <= COMPUTE_V;
                        d_reg <= d;
                        multiplier_reg <= MULTIPLIER;
                        product_v <= 30'd0;
                        remainder_v <= 30'd0;
                        mult_counter <= 6'd0;
                    end
                end

                COMPUTE_V: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (mult_counter < 6'd20) begin
                        if (d_reg[0]) begin
                            product_v <= product_v + multiplier_reg;
                        end
                        d_reg <= d_reg >> 1;
                        multiplier_reg <= multiplier_reg << 1;
                        mult_counter <= mult_counter + 6'd1;
                    end else begin
                        remainder_v <= product_v % mod_reg;
                        v <= remainder_v;
                        state <= COMPUTE_B;
                    end
                end

                COMPUTE_B: begin
                    cycle_count <= cycle_count + 8'd1;
                    b <= u * N + 64'd1;
                    state <= COMPUTE_E;
                end

                COMPUTE_E: begin
                    cycle_count <= cycle_count + 8'd1;
                    e <= v * N;
                    state <= FINISH;
                end

                FINISH: begin
                    valid <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule