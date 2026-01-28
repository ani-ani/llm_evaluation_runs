module largest_prime_factor(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] n_in,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] CHECK_SQRT = 3'd1;
    localparam [2:0] DIVIDE     = 3'd2;
    localparam [2:0] UPDATE     = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [15:0] n_reg;           // Captured n_in
    reg [15:0] remaining;       // Current remaining value
    reg [15:0] max_factor;      // Current largest prime factor
    reg [7:0] candidate;        // Odd divisor candidate (8 bits, max 255)
    reg [7:0] cycle_count;      // Cycle counter to prevent infinite loops
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Temporary values for calculation
    reg [15:0] temp_remaining;
    reg [7:0] temp_candidate;
    
    // Square check result
    wire [15:0] candidate_sq;
    wire sqrt_check;
    
    // Calculate candidate * candidate (fits 16 bits: 255*255 = 65025)
    assign candidate_sq = candidate * candidate;
    assign sqrt_check = (candidate_sq <= remaining);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            n_reg <= 16'd0;
            remaining <= 16'd0;
            max_factor <= 16'd0;
            candidate <= 8'd0;
            cycle_count <= 8'd0;
            temp_remaining <= 16'd0;
            temp_candidate <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        n_reg <= n_in;
                        // Initialize algorithm
                        remaining <= n_in;
                        max_factor <= 16'd1;
                        candidate <= 8'd3;
                        state <= CHECK_SQRT;
                    end
                end

                CHECK_SQRT: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if candidate^2 <= remaining
                    // If n is 2, remaining becomes 1 immediately, so max_factor stays 1
                    // After loop, if remaining > 1, max_factor = remaining
                    if (!sqrt_check || remaining <= 8'd1 || cycle_count >= MAX_CYCLES) begin
                        // Loop exit condition
                        if (remaining > 16'd1) begin
                            max_factor <= remaining;
                        end
                        state <= DONE_STATE;
                    end else begin
                        state <= DIVIDE;
                    end
                end

                DIVIDE: begin
                    // Check if remaining % candidate == 0
                    if (remaining % candidate == 16'd0) begin
                        temp_remaining <= remaining / candidate;
                        temp_candidate <= candidate;
                        state <= UPDATE;
                    end else begin
                        // Not divisible, increment candidate by 2
                        candidate <= candidate + 8'd2;
                        state <= CHECK_SQRT;
                    end
                end

                UPDATE: begin
                    // Update remaining and max_factor
                    remaining <= temp_remaining;
                    max_factor <= {8'd0, temp_candidate};
                    // Keep same candidate for repeated division
                    state <= CHECK_SQRT;
                end

                DONE_STATE: begin
                    result <= max_factor;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule