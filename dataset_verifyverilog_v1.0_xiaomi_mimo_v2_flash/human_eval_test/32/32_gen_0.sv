module find_zero(
    input clk,
    input rst_n,
    input start,
    input signed [15:0] coeffs [0:7],
    input [2:0] num_coeffs,
    output reg signed [31:0] result,
    output reg done
);
    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] EVAL = 2'd1;
    localparam [1:0] UPDATE = 2'd2;
    localparam [1:0] FINISH = 2'd3;

    // Constants for Q16.16 format
    localparam signed [31:0] INIT_LOW = 32'hFFF60000;  // -10.0
    localparam signed [31:0] INIT_HIGH = 32'h000A0000; // 10.0
    localparam signed [31:0] TWO = 32'h00020000;       // 2.0
    
    // Registers for binary search
    reg [1:0] state;
    reg [2:0] iter_count;
    reg signed [31:0] low;
    reg signed [31:0] high;
    reg signed [31:0] mid;
    reg signed [31:0] poly_result;
    
    // Registers for polynomial evaluation
    reg [2:0] coeff_index;
    reg signed [63:0] accum;
    reg signed [31:0] current_x;
    
    // Control registers
    reg eval_start;
    reg eval_done;
    reg [2:0] valid_coeffs;
    
    // Output done signal
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
        end else begin
            if (state == FINISH) begin
                done <= 1'b1;
            end else if (state == IDLE && start) begin
                done <= 1'b0;
            end
        end
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            low <= INIT_LOW;
            high <= INIT_HIGH;
            mid <= 32'd0;
            iter_count <= 3'd0;
            eval_start <= 1'b0;
            coeff_index <= 3'd0;
            accum <= 64'd0;
            current_x <= 32'd0;
            poly_result <= 32'd0;
            valid_coeffs <= 3'd0;
        end else begin
            case (state)
                IDLE: begin
                    eval_start <= 1'b0;
                    if (start) begin
                        // Initialize binary search
                        low <= INIT_LOW;
                        high <= INIT_HIGH;
                        iter_count <= 3'd0;
                        valid_coeffs <= num_coeffs;
                        state <= EVAL;
                    end
                end

                EVAL: begin
                    // Calculate mid = (low + high) >> 1
                    mid <= (low + high) >>> 1;
                    current_x <= (low + high) >>> 1;
                    eval_start <= 1'b1;
                    state <= UPDATE;
                end

                UPDATE: begin
                    eval_start <= 1'b0;
                    
                    if (poly_result > 32'd0) begin
                        high <= mid;
                    end else begin
                        low <= mid;
                    end
                    
                    if (iter_count >= 3'd7) begin
                        result <= mid;
                        state <= FINISH;
                    end else begin
                        iter_count <= iter_count + 3'd1;
                        state <= EVAL;
                    end
                end

                FINISH: begin
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Polynomial evaluation combinational logic
    // Using Horner's method: ((((c7*x + c6)*x + c5)*x + ...)*x + c0)
    always @(*) begin
        // Initialize with highest coefficient
        accum = {{48{coeffs[7][15]}}, coeffs[7]};  // Sign-extend to 64-bit
        
        // Handle up to 8 coefficients
        if (valid_coeffs >= 3'd8) begin
            accum = accum * current_x;
            accum = accum + {{48{coeffs[6][15]}}, coeffs[6]};
        end
        if (valid_coeffs >= 3'd7) begin
            accum = accum * current_x;
            accum = accum + {{48{coeffs[5][15]}}, coeffs[5]};
        end
        if (valid_coeffs >= 3'd6) begin
            accum = accum * current_x;
            accum = accum + {{48{coeffs[4][15]}}, coeffs[4]};
        end
        if (valid_coeffs >= 3'd5) begin
            accum = accum * current_x;
            accum = accum + {{48{coeffs[3][15]}}, coeffs[3]};
        end
        if (valid_coeffs >= 3'd4) begin
            accum = accum * current_x;
            accum = accum + {{48{coeffs[2][15]}}, coeffs[2]};
        end
        if (valid_coeffs >= 3'd3) begin
            accum = accum * current_x;
            accum = accum + {{48{coeffs[1][15]}}, coeffs[1]};
        end
        if (valid_coeffs >= 3'd2) begin
            accum = accum * current_x;
            accum = accum + {{48{coeffs[0][15]}}, coeffs[0]};
        end
        
        // Truncate to 32-bit (keep middle 32 bits for Q16.16)
        // After multiplication, we want bits [47:16]
        poly_result = accum[47:16];
    end
endmodule