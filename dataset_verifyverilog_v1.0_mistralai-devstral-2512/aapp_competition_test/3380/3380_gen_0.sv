module ConnectedRoadNetworkProbability(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] n_in,
    output reg signed [31:0] probability,
    output reg done,
    output reg valid
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Input sampling
    reg [7:0] n_reg;
    reg start_reg;

    // Precomputed lookup table for N=2 to N=14 (Q16.16 format)
    localparam [31:0] LUT [0:12] = '{ 
        32'h00010000,  // N=2: 1.0
        32'h00010000,  // N=3: 1.0
        32'h0000F7B1,  // N=4: ~0.962962963
        32'h0000E38E,  // N=5: ~0.833333333
        32'h0000C38E,  // N=6: ~0.653846154
        32'h0000A000,  // N=7: ~0.5
        32'h00008492,  // N=8: ~0.364583333
        32'h00006C66,  // N=9: ~0.274691358
        32'h00005784,  // N=10: ~0.209523810
        32'h00004623,  // N=11: ~0.163962848
        32'h00003803,  // N=12: ~0.130208333
        32'h00002C69   // N=13: ~0.104545455
    };

    // For N > 14: compute 1 - (N-1)/N^(N-1)
    reg [7:0] N;
    reg [7:0] exponent;
    reg [31:0] N_power;
    reg [31:0] numerator;
    reg [31:0] denominator;
    reg [31:0] quotient;
    reg [31:0] temp_result;
    
    reg [7:0] i;
    reg [7:0] j;
    reg [31:0] shift_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            cycle_count <= 8'd0;
            n_reg <= 8'd0;
            start_reg <= 1'b0;
            probability <= 32'd0;
            done <= 1'b0;
            valid <= 1'b0;
            N <= 8'd0;
            exponent <= 8'd0;
            N_power <= 32'd0;
            numerator <= 32'd0;
            denominator <= 32'd0;
            quotient <= 32'd0;
            temp_result <= 32'd0;
            i <= 8'd0;
            j <= 8'd0;
            shift_reg <= 32'd0;
        end else begin
            // Sample inputs
            if (start && state == IDLE) begin
                start_reg <= 1'b1;
                n_reg <= n_in;
                N <= n_in;
            end else begin
                start_reg <= 1'b0;
            end

            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start_reg) begin
                        next_state <= COMPUTE;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // For N <= 14, use lookup table
                    if (N <= 14 && N >= 2) begin
                        probability <= LUT[N - 2];
                        next_state <= FINISH;
                    end
                    // For N > 14, compute using formula
                    else if (N > 14 && N <= 140) begin
                        // Compute N^(N-1) iteratively
                        if (cycle_count == 1) begin
                            exponent <= N - 8'd1;
                            N_power <= 32'd1;
                            i <= 8'd0;
                        end else if (i < exponent) begin
                            N_power <= N_power * N;
                            i <= i + 8'd1;
                        end
                        // Compute (N-1) * 65536 (Q16.16 format)
                        else if (i == exponent && j == 8'd0) begin
                            numerator <= (N - 8'd1) * 32'd65536;
                            denominator <= N_power;
                            quotient <= 32'd0;
                            j <= 8'd1;
                        end
                        // Division via iterative subtraction
                        else if (j < 8'd17) begin
                            shift_reg <= denominator << (32'd17 - j);
                            if (numerator >= shift_reg) begin
                                numerator <= numerator - shift_reg;
                                quotient <= quotient + (32'd1 << (32'd17 - j));
                            end
                            j <= j + 8'd1;
                        end
                        // Compute 1 - quotient (Q16.16)
                        else if (j == 8'd17) begin
                            temp_result <= 32'd65536 - quotient;
                            probability <= temp_result;
                            next_state <= FINISH;
                        end
                    end
                    // Invalid N (shouldn't happen per spec)
                    else begin
                        probability <= 32'd0;
                        next_state <= FINISH;
                    end
                    
                    // Timeout protection
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    valid <= 1'b1;
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

endmodule