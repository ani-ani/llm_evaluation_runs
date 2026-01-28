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
localparam [2:0] COMPLETE = 3'd4;

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
reg [5:0] div_count;
reg [21:0] rem;

// Main FSM
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        result <= 24'd0;
        best_result <= 24'hFFFFFF;
        idx_i <= 4'd0;
        idx_j <= 4'd0;
        temp_result <= 24'd0;
        d0 <= 24'd0;
        d1 <= 24'd0;
        pair_days <= 24'd0;
        div_start <= 1'b0;
        num_d0 <= 22'd0;
        num_d1 <= 22'd0;
        denom <= 16'd0;
        div_count <= 6'd0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    state <= COMPUTE_SINGLE;
                    idx_i <= 4'd0;
                    best_result <= 24'hFFFFFF;
                    div_count <= 6'd0;
                end
            end
            
            COMPUTE_SINGLE: begin
                if (idx_i < n) begin
                    if (div_count == 6'd0) begin
                        div_start <= 1'b1;
                        dividend <= {p, 12'd0};
                        divisor <= a[idx_i];
                        div_count <= 6'd1;
                    end
                    else if (div_count == 6'd1) begin
                        div_start <= 1'b1;
                        dividend <= {q, 12'd0};
                        divisor <= b[idx_i];
                        div_count <= 6'd2;
                    end
                    else if (div_count == 6'd2 && div_done) begin
                        temp_result <= quotient;
                        div_count <= 6'd3;
                    end
                    else if (div_count == 6'd3 && div_done) begin
                        if (quotient > temp_result) temp_result <= quotient;
                        div_count <= 6'd4;
                    end
                    else if (div_count == 6'd4) begin
                        if (temp_result < best_result) best_result <= temp_result;
                        div_count <= 6'd0;
                        idx_i <= idx_i + 4'd1;
                    end
                end
                else begin
                    state <= COMPUTE_PAIR;
                    idx_i <= 4'd0;
                    idx_j <= 4'd1;
                    div_count <= 6'd0;
                end
            end
            
            COMPUTE_PAIR: begin
                if (idx_i < n && idx_j < n) begin
                    if (div_count == 6'd0) begin
                        num_d0 <= (b[idx_j] * p - a[idx_j] * q) * 12'd4096;
                        num_d1 <= (a[idx_i] * q - b[idx_i] * p) * 12'd4096;
                        denom <= a[idx_i] * b[idx_j] - b[idx_i] * a[idx_j];
                        div_count <= 6'd1;
                    end
                    else if (div_count == 6'd1) begin
                        if (denom != 16'd0 && $signed(num_d0) >= 0 && $signed(num_d1) >= 0) begin
                            div_start <= 1'b1;
                            dividend <= num_d0;
                            divisor <= denom[7:0];
                            div_count <= 6'd2;
                        end else div_count <= 6'd6;
                    end
                    else if (div_count == 6'd2 && div_done) begin
                        d0 <= $signed(quotient);
                        div_start <= 1'b1;
                        dividend <= num_d1;
                        divisor <= denom[7:0];
                        div_count <= 6'd3;
                    end
                    else if (div_count == 6'd3 && div_done) begin
                        d1 <= $signed(quotient);
                        div_count <= 6'd4;
                    end
                    else if (div_count == 6'd4) begin
                        if (d0 >= 24'd0 && d1 >= 24'd0) begin
                            pair_days <= d0 + d1;
                            div_count <= 6'd5;
                        end else div_count <= 6'd6;
                    end
                    else if (div_count == 6'd5) begin
                        if (pair_days < best_result) best_result <= pair_days;
                        div_count <= 6'd6;
                    end
                    else if (div_count == 6'd6) begin
                        div_count <= 6'd0;
                        if (idx_j == (n - 4'd1)) begin
                            idx_i <= idx_i + 4'd1;
                            idx_j <= idx_i + 4'd2;
                        end else idx_j <= idx_j + 4'd1;
                    end
                end
                else state <= COMPLETE;
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

// Divider implementation
assign quotient = rem / divisor;
assign div_done = (div_count == 6'd24);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rem <= 22'd0;
    end else if (div_start) begin
        rem <= dividend;
    end else if (div_count < 6'd24 && divisor != 8'd0) begin
        rem <= rem << 1;
        if (rem >= {14'd0, divisor}) begin
            rem <= rem - {14'd0, divisor};
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        div_count <= 6'd0;
    end else if (div_start) begin
        div_count <= 6'd1;
    end else if (div_count < 6'd24) begin
        div_count <= div_count + 6'd1;
    end
end

endmodule