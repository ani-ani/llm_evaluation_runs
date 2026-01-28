module find_zero(
    input clk,
    input rst_n,
    input start,
    input signed [15:0] coeffs [0:7],
    input [2:0] num_coeffs,
    output reg signed [31:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE   = 2'd0;
    localparam [1:0] EVAL   = 2'd1;
    localparam [1:0] UPDATE = 2'd2;
    localparam [1:0] DONE   = 2'd3;

    // Internal registers
    reg [1:0] state, next_state;
    reg signed [31:0] low, high, mid;
    reg signed [31:0] f_mid;
    reg [3:0] iter_count;
    reg [3:0] coeff_index;
    reg signed [63:0] poly_accum;
    reg signed [31:0] poly_result;

    // Constants
    localparam signed [31:0] INIT_LOW  = 32'sd-655360;
    localparam signed [31:0] INIT_HIGH = 32'sd655360;
    localparam [3:0] MAX_ITER = 4'd8;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            result <= 32'sd0;
            done <= 1'b0;
            low <= 32'sd0;
            high <= 32'sd0;
            mid <= 32'sd0;
            f_mid <= 32'sd0;
            iter_count <= 4'd0;
            coeff_index <= 4'd0;
            poly_accum <= 64'sd0;
            poly_result <= 32'sd0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        low <= INIT_LOW;
                        high <= INIT_HIGH;
                        iter_count <= 4'd0;
                        next_state <= EVAL;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                EVAL: begin
                    // Calculate mid point
                    mid <= (low + high) >>> 1;
                    
                    // Initialize polynomial evaluation
                    coeff_index <= num_coeffs;
                    poly_accum <= 64'sd0;
                    
                    // Start with highest coefficient
                    if (num_coeffs > 0) begin
                        poly_accum <= {32'd0, coeffs[num_coeffs]};
                        coeff_index <= num_coeffs - 1;
                    end
                    
                    next_state <= UPDATE;
                end

                UPDATE: begin
                    // Polynomial evaluation using Horner's method
                    if (coeff_index >= 0) begin
                        poly_accum <= poly_accum * mid + {32'd0, coeffs[coeff_index]};
                        coeff_index <= coeff_index - 1;
                        next_state <= UPDATE;
                    end else begin
                        // Evaluation complete
                        poly_result <= poly_accum[63:32];
                        f_mid <= poly_result;
                        
                        // Update bounds based on sign
                        if (f_mid > 32'sd0) begin
                            high <= mid;
                        end else begin
                            low <= mid;
                        end
                        
                        // Increment iteration count
                        iter_count <= iter_count + 1;
                        
                        // Check if done
                        if (iter_count >= MAX_ITER - 1) begin
                            result <= mid;
                            next_state <= DONE;
                        end else begin
                            next_state <= EVAL;
                        end
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule