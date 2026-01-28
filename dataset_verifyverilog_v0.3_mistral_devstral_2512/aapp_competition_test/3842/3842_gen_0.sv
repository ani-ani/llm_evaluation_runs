module min_days_solver (
    input wire clk,
    input wire rst_n,
    input wire start,
    
    // Requirements (0-1023)
    input wire [9:0] p,
    input wire [9:0] q,
    
    // Number of projects (1-16)
    input wire [3:0] n,
    
    // Project arrays - 16 elements max, each 8-bit
    // Access pattern: arr[i] for i in 0-15
    input wire [7:0] a [0:15],
    input wire [7:0] b [0:15],
    
    // Result in Q12.12 format (12 integer + 12 fractional bits)
    output reg [23:0] result,
    output reg done
);

// Internal states
localparam [2:0] IDLE = 3'd0;
localparam [2:0] COMPUTE_SINGLE = 3'd1;
localparam [2:0] COMPUTE_PAIR = 3'd2;
localparam [2:0] COMPLETE = 3'd3;

reg [2:0] state;
reg [3:0] idx_i, idx_j;  // Project indices
reg [23:0] best_result;   // Best result so far (Q12.12)
reg [23:0] temp_result;   // Temporary calculation

// Division unit signals
reg div_start;
wire div_done;
reg [21:0] dividend;   // For p*4096 (p*2^12)
reg [7:0] divisor;     // a_i or b_i
wire [23:0] quotient;  // Q12.12 result

// Pair calculation signals
reg [21:0] num_d0;     // numerator for d0: b1*p - a1*q
reg [21:0] num_d1;     // numerator for d1: -(b0*p - a0*q)
reg [15:0] denom;      // denominator: a0*b1 - b0*a1
reg signed [23:0] d0, d1;  // Q12.12 results
reg signed [23:0] pair_days;

// Simple divider (restoring division) for Q12.12
// Computes dividend / divisor -> quotient in Q12.12
// dividend = value * 4096, divisor = divisor_value
reg [5:0] div_count;
reg [21:0] rem;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        result <= 24'd0;
        best_result <= 24'hFFFFFF;  // Initialize to max
        div_start <= 1'b0;
        div_count <= 6'd0;
        idx_i <= 4'd0;
        idx_j <= 4'd0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    state <= COMPUTE_SINGLE;
                    idx_i <= 4'd0;
                    best_result <= 24'hFFFFFF;
                end
            end
            
            COMPUTE_SINGLE: begin
                if (idx_i < n) begin
                    // Compute max(p/a_i, q/b_i) for project idx_i
                    // Each division: (p * 4096) / a_i, result in Q12.12
                    if (div_count == 6'd0) begin
                        // Start first division
                        div_start <= 1'b1;
                        dividend <= {p, 12'd0};  // p * 4096
                        divisor <= a[idx_i];
                        div_count <= 6'd1;
                    end else if (div_count == 6'd1) begin
                        // Start second division
                        div_start <= 1'b1;
                        dividend <= {q, 12'd0};  // q * 4096
                        divisor <= b[idx_i];
                        div_count <= 6'd2;
                    end else if (div_count == 6'd2 && div_done) begin
                        // First division done, store result
                        temp_result <= quotient;  // p/a_i in Q12.12
                        div_count <= 6'd3;
                    end else if (div_count == 6'd3 && div_done) begin
                        // Second division done
                        // Compare p/a_i and q/b_i, take max
                        if (quotient > temp_result) begin
                            temp_result <= quotient;
                        end
                        div_count <= 6'd4;
                    end else if (div_count == 6'd4) begin
                        // Update best result
                        if (temp_result < best_result) begin
                            best_result <= temp_result;
                        end
                        div_count <= 6'd0;
                        idx_i <= idx_i + 4'd1;
                    end
                end else begin
                    state <= COMPUTE_PAIR;
                    idx_i <= 4'd0;
                    idx_j <= 4'd1;
                    div_count <= 6'd0;
                end
            end
            
            COMPUTE_PAIR: begin
                if (idx_i < n && idx_j < n) begin
                    // Compute d0 and d1 for pair (idx_i, idx_j)
                    // d0 = (b1*p - a1*q) / (a0*b1 - b0*a1)
                    // d1 = -(b0*p - a0*q) / (a0*b1 - b0*a1)
                    
                    if (div_count == 6'd0) begin
                        // Calculate numerator values in Q12.12 format
                        // num_d0 = b1*p - a1*q, then * 4096 for division
                        // num_d1 = -(b0*p - a0*q), then * 4096
                        // denom = a0*b1 - b0*a1
                        
                        // Use 32-bit intermediates to avoid overflow
                        num_d0 <= (b[idx_j] * p - a[idx_j] * q) * 4096;
                        num_d1 <= -(b[idx_i] * p - a[idx_i] * q) * 4096;
                        denom <= a[idx_i] * b[idx_j] - b[idx_i] * a[idx_j];
                        
                        div_count <= 6'd1;
                    end else if (div_count == 6'd1) begin
                        // Check if denominator is non-zero and positive
                        if (denom != 16'd0 && num_d0 >= 22'd0 && num_d1 >= 22'd0) begin
                            // Start division for d0
                            div_start <= 1'b1;
                            dividend <= num_d0[21:0];
                            divisor <= denom[7:0];  // Truncate to 8-bit for division
                            div_count <= 6'd2;
                        end else begin
                            // Skip this pair
                            div_count <= 6'd6;
                        end
                    end else if (div_count == 6'd2 && div_done) begin
                        d0 <= quotient;
                        // Start division for d1
                        div_start <= 1'b1;
                        dividend <= num_d1[21:0];
                        divisor <= denom[7:0];
                        div_count <= 6'd3;
                    end else if (div_count == 6'd3 && div_done) begin
                        d1 <= quotient;
                        div_count <= 6'd4;
                    end else if (div_count == 6'd4) begin
                        // Check if d0 + d1 is valid (both positive)
                        if (d0 >= 24'd0 && d1 >= 24'd0) begin
                            pair_days <= d0 + d1;
                            div_count <= 6'd5;
                        end else begin
                            div_count <= 6'd6;
                        end
                    end else if (div_count == 6'd5) begin
                        // Update best result
                        if (pair_days < best_result) begin
                            best_result <= pair_days;
                        end
                        div_count <= 6'd6;
                    end else if (div_count == 6'd6) begin
                        // Move to next pair
                        div_count <= 6'd0;
                        if (idx_j == n - 4'd1) begin
                            idx_i <= idx_i + 4'd1;
                            idx_j <= idx_i + 4'd2;
                        end else begin
                            idx_j <= idx_j + 4'd1;
                        end
                    end
                end else begin
                    state <= COMPLETE;
                end
            end
            
            COMPLETE: begin
                result <= best_result;
                done <= 1'b1;
                state <= IDLE;
            end
            
            default: state <= IDLE;
        endcase
    end
end

// Divider instantiation (simplified restoring division)
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        div_done <= 1'b0;
        quotient <= 24'd0;
        rem <= 22'd0;
    end else if (div_start) begin
        // Initialize division
        rem <= dividend;
        quotient <= 24'd0;
        div_done <= 1'b0;
    end else if (div_count > 6'd0 && !div_done) begin
        // 24 cycles for 24-bit result
        if (divisor != 8'd0) begin
            rem <= rem << 1;
            quotient <= quotient << 1;
            if (rem[21:14] >= divisor) begin  // Compare MSBs
                rem[21:14] <= rem[21:14] - divisor;
                quotient[0] <= 1'b1;
            end
        end
        if (div_count == 6'd24) begin
            div_done <= 1'b1;
            div_count <= 6'd0;
        end
    end
end

endmodule