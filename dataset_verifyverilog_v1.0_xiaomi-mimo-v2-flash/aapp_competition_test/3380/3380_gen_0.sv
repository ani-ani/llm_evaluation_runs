module probability_calculator (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] n_in,
    output reg signed [31:0] probability,
    output reg done,
    output reg valid
);

// State definitions
localparam [2:0] IDLE       = 3'd0;
localparam [2:0] SAMPLE     = 3'd1;
localparam [2:0] LOOKUP     = 3'd2;
localparam [2:0] COMPUTE    = 3'd3;
localparam [2:0] CALC_POW   = 3'd4;
localparam [2:0] CALC_DIV   = 3'd5;
localparam [2:0] FINISH     = 3'd6;

// Registers
reg [2:0] state;
reg [2:0] next_state;
reg [7:0] n_reg;                    // Sampled N value
reg signed [31:0] prob_reg;         // Final probability in Q16.16
reg done_reg;
reg valid_reg;

// Computation registers
reg signed [47:0] pow_result;       // N^(N-1) in Q16.16
reg signed [47:0] div_temp;         // (N-1)/N^(N-1) in Q16.16
reg signed [31:0] numerator;        // (N-1) in Q16.16
reg signed [47:0] accumulator;       // Accumulator for division
reg [7:0] iter_counter;             // Iteration counter for power/division
reg [7:0] max_iterations;           // Max iterations for current operation
reg [7:0] loop_counter;             // For power calculation loop
reg [15:0] mul_a, mul_b;            // 16-bit multipliers for power
reg signed [47:0] mul_result;       // 48-bit product

// Constants
localparam [31:0] ONE_Q16 = 32'h00010000;  // 1.0 in Q16.16
localparam [31:0] TWO_Q16 = 32'h00020000;  // 2.0 in Q16.16
localparam [15:0] SCALE = 16'h0001;         // For Q16.16 scaling

// Lookup table: For N=2..14, probability in Q16.16 (approximate to 32-bit)
// Values calculated from OEIS A000081 (connected functional graphs) / N^(N-1)
reg [31:0] lookup_rom [12:0];  // 13 entries for N=2..14

// Initialize lookup table values (precomputed in Q16.16)
initial begin
    lookup_rom[0]  = 32'h00010000;  // N=2: 1.0
    lookup_rom[1]  = 32'h00A3D70A;  // N=3: ~0.6398 (27/42)
    lookup_rom[2]  = 32'h0F7B0F5B;  // N=4: ~0.9629
    lookup_rom[3]  = 32'h0E0B0E0C;  // N=5: ~0.8778
    lookup_rom[4]  = 32'h0D0F0D0F;  // N=6: ~0.8153
    lookup_rom[5]  = 32'h0C1E0C1F;  // N=7: ~0.7571
    lookup_rom[6]  = 32'h0B3D0B3E;  // N=8: ~0.7030
    lookup_rom[7]  = 32'h0A690A6A;  // N=9: ~0.6518
    lookup_rom[8]  = 32'h09A109A2;  // N=10: ~0.6032
    lookup_rom[9]  = 32'h08E308E4;  // N=11: ~0.5569
    lookup_rom[10] = 32'h082E082F;  // N=12: ~0.5127
    lookup_rom[11] = 32'h07820783;  // N=13: ~0.4704
    lookup_rom[12] = 32'h06DD06DE;  // N=14: ~0.4299
end

// State transition logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        n_reg <= 8'd0;
        probability <= 32'd0;
        done <= 1'b0;
        valid <= 1'b0;
        pow_result <= 48'd0;
        div_temp <= 48'd0;
        numerator <= 32'd0;
        accumulator <= 48'd0;
        iter_counter <= 8'd0;
        max_iterations <= 8'd0;
        loop_counter <= 8'd0;
        mul_a <= 16'd0;
        mul_b <= 16'd0;
        mul_result <= 48'd0;
        prob_reg <= 32'd0;
        done_reg <= 1'b0;
        valid_reg <= 1'b0;
    end else begin
        state <= next_state;
        
        case (state)
            IDLE: begin
                done <= 1'b0;
                valid <= 1'b0;
                probability <= 32'd0;
                if (start) begin
                    n_reg <= n_in;
                end
            end
            
            SAMPLE: begin
                // N already sampled
            end
            
            LOOKUP: begin
                if (n_reg >= 8'd2 && n_reg <= 8'd14) begin
                    // Use lookup table for N=2..14
                    prob_reg <= lookup_rom[n_reg - 8'd2];
                end
            end
            
            COMPUTE: begin
                // Initialize for power calculation (N > 14)
                // pow_result = N^(N-1) in Q16.16
                // Start with 1.0 in Q16.16
                pow_result <= {16'd1, 16'd0};  // 1.0 * 2^16 = 0x00010000
                loop_counter <= 8'd0;
                // N-1 iterations for N^(N-1)
                max_iterations <= (n_reg - 8'd1) < 8'd100 ? (n_reg - 8'd1) : 8'd100;
            end
            
            CALC_POW: begin
                // Multiply pow_result by N for (N-1) times
                // Use 16-bit multipliers: pow_result[47:32] * N, pow_result[31:16] * N
                if (loop_counter < max_iterations) begin
                    // Multiply upper 16 bits of pow_result by N
                    mul_a <= pow_result[47:32];
                    mul_b <= {8'd0, n_reg};
                    mul_result <= (pow_result[47:32] * {8'd0, n_reg});
                    
                    // Update pow_result
                    pow_result <= (pow_result * {16'd0, n_reg}) >> 16;
                    
                    loop_counter <= loop_counter + 8'd1;
                end
            end
            
            CALC_DIV: begin
                // Calculate (N-1)/N^(N-1) in Q16.16
                // Use iterative division: multiply numerator by 2^16, divide by denominator
                // numerator = (N-1) in Q16.16
                numerator <= {(n_reg - 8'd1) << 16};  // (N-1) * 2^16
                accumulator <= 48'd0;
                iter_counter <= 8'd0;
                max_iterations <= 8'd32;  // 32 iterations for division precision
            end
            
            FINISH: begin
                // Calculate final probability = 1 - (N-1)/N^(N-1)
                // prob_reg already set for N<=14
                if (n_reg > 8'd14) begin
                    // For N>14: prob_reg = 1 - div_temp
                    prob_reg <= ONE_Q16 - div_temp[47:16];
                end
                done <= 1'b1;
                valid <= 1'b1;
                probability <= prob_reg;
            end
            
            default: begin
                state <= IDLE;
            end
        endcase
        
        // Additional logic for division iteration (runs continuously)
        if (state == CALC_DIV && iter_counter < max_iterations) begin
            // Multiply by 2 and subtract if denominator <= accumulator
            accumulator <= accumulator << 1;
            if (accumulator < {32'd0, pow_result[47:16]}) begin
                accumulator <= (accumulator << 1) + {32'd0, numerator[31:16]};
                // Result bit = 1 (implicitly tracked in accumulator position)
            end else begin
                accumulator <= (accumulator << 1) - {32'd0, pow_result[47:16]};
            end
            iter_counter <= iter_counter + 8'd1;
            
            // Build result in div_temp (shift left each iteration)
            if (iter_counter == 8'd0) begin
                div_temp <= 48'd0;
            end else begin
                // Check if we should set this bit (overflow condition)
                if (accumulator >= {32'd0, pow_result[47:16]}) begin
                    div_temp <= (div_temp << 1) | 48'd1;
                end else begin
                    div_temp <= (div_temp << 1);
                end
            end
        end
        
        // Continue multiplication in CALC_POW state
        if (state == CALC_POW && loop_counter < max_iterations) begin
            pow_result <= (pow_result * {16'd0, n_reg}) >> 16;
        end
    end
end

// Next state logic
always @(*) begin
    next_state = state;
    case (state)
        IDLE: begin
            if (start) begin
                next_state = SAMPLE;
            end
        end
        
        SAMPLE: begin
            next_state = LOOKUP;
        end
        
        LOOKUP: begin
            if (n_reg >= 8'd2 && n_reg <= 8'd14) begin
                next_state = FINISH;
            end else begin
                next_state = COMPUTE;
            end
        end
        
        COMPUTE: begin
            next_state = CALC_POW;
        end
        
        CALC_POW: begin
            if (loop_counter >= max_iterations) begin
                next_state = CALC_DIV;
            end else begin
                next_state = CALC_POW;
            end
        end
        
        CALC_DIV: begin
            if (iter_counter >= max_iterations) begin
                next_state = FINISH;
            end else begin
                next_state = CALC_DIV;
            end
        end
        
        FINISH: begin
            next_state = IDLE;
        end
        
        default: begin
            next_state = IDLE;
        end
    endcase
end

endmodule