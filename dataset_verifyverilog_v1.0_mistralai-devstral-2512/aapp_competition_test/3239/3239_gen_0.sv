module pokeball_cost_calculator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] N_in,
    input wire [9:0] P_in,
    output reg [31:0] result,
    output reg done,
    output reg valid
);

    // State declarations
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] COMPUTE_PROB = 4'd1;
    localparam [3:0] COMPUTE_EXPECTED = 4'd2;
    localparam [3:0] COMPUTE_COST = 4'd3;
    localparam [3:0] FINAL = 4'd4;
    localparam [3:0] DONE_STATE = 4'd5;

    reg [3:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Intermediate registers
    reg signed [31:0] prob_100;          // (1-P)^100 in Q16.16
    reg signed [31:0] expected_pokemon;  // 1/(1-prob_100) in Q16.16
    reg signed [31:0] cost_per_pokemon;  // 5/expected_pokemon in Q16.16
    reg signed [31:0] total_cost;        // cost_per_pokemon * N in Q16.16

    // Iteration counters
    reg [6:0] iter_count;
    reg [3:0] nr_iter_count;

    // Newton-Raphson variables
    reg signed [31:0] x;                  // Current estimate
    reg signed [31:0] x_next;             // Next estimate
    reg signed [31:0] denominator;        // 1 - prob_100

    // Convert P_in to Q16.16 (P_in is 0-1000 representing 0.000-1.000)
    wire signed [31:0] P_fixed = ({16'd0, P_in} * 256) >> 8;
    wire signed [31:0] one_minus_P = 32'd65536 - P_fixed;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            valid <= 1'b0;
            cycle_count <= 8'd0;
            iter_count <= 7'd0;
            nr_iter_count <= 4'd0;
            prob_100 <= 32'd0;
            expected_pokemon <= 32'd0;
            cost_per_pokemon <= 32'd0;
            total_cost <= 32'd0;
            x <= 32'd0;
            x_next <= 32'd0;
            denominator <= 32'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    if (start) begin
                        next_state <= COMPUTE_PROB;
                        prob_100 <= one_minus_P;  // Start with (1-P)
                        iter_count <= 7'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                COMPUTE_PROB: begin
                    // Compute (1-P)^100 using 100 iterations
                    if (iter_count < 7'd99) begin
                        prob_100 <= (prob_100 * one_minus_P) >> 16;  // Q16.16 multiply
                        iter_count <= iter_count + 7'd1;
                        next_state <= COMPUTE_PROB;
                    end else begin
                        // Final iteration
                        prob_100 <= (prob_100 * one_minus_P) >> 16;
                        denominator <= 32'd65536 - prob_100;  // 1 - (1-P)^100 in Q16.16
                        
                        // Handle edge cases
                        if (P_in == 10'd0) begin
                            // P=0: infinite cost, clamp to max
                            result <= 32'd2147483647;  // Max positive Q16.16
                            valid <= 1'b1;
                            next_state <= DONE_STATE;
                        end else if (P_in == 10'd1000) begin
                            // P=1: cost = 0.05 per Pokemon
                            cost_per_pokemon <= 32'd3;  // 0.05 in Q16.16 (5/100)
                            next_state <= FINAL;
                        end else begin
                            // Initialize Newton-Raphson
                            x <= 32'd65536;  // Initial guess = 1.0
                            nr_iter_count <= 4'd0;
                            next_state <= COMPUTE_EXPECTED;
                        end
                    end
                end

                COMPUTE_EXPECTED: begin
                    // Newton-Raphson iteration: x_next = x * (2 - denominator * x)
                    // Compute denominator * x (Q16.16 * Q16.16 = Q32.32)
                    wire signed [63:0] temp = $signed(denominator) * $signed(x);
                    wire signed [31:0] dx = temp[47:16];  // Take middle 32 bits (Q16.16)
                    
                    x_next <= (x * (32'd131072 - dx)) >> 17;  // 2.0 - dx, then multiply by x
                    
                    if (nr_iter_count < 4'd15) begin
                        x <= x_next;
                        nr_iter_count <= nr_iter_count + 4'd1;
                        next_state <= COMPUTE_EXPECTED;
                    end else begin
                        expected_pokemon <= x_next;
                        next_state <= COMPUTE_COST;
                    end
                end

                COMPUTE_COST: begin
                    // Compute 5 / expected_pokemon
                    // 5 in Q16.16 is 5 * 65536 = 325120
                    wire signed [31:0] numerator = 32'd325120;
                    
                    // Newton-Raphson for reciprocal
                    x <= expected_pokemon;  // Initial guess
                    nr_iter_count <= 4'd0;
                    next_state <= COMPUTE_COST;
                end

                FINAL: begin
                    // Multiply cost_per_pokemon by N_in
                    wire signed [63:0] temp_total = $signed(cost_per_pokemon) * $signed(N_in);
                    total_cost <= temp_total[47:16];  // Q16.16 result
                    
                    result <= total_cost;
                    valid <= 1'b1;
                    next_state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                    valid <= 1'b0;
                end
            endcase
        end
    end

    // Handle P=1 case separately (cost = 5*N/100)
    always @(posedge clk) begin
        if (state == COMPUTE_COST && P_in == 10'd1000) begin
            cost_per_pokemon <= 32'd3;  // 0.05 in Q16.16
            next_state <= FINAL;
        end
    end

endmodule