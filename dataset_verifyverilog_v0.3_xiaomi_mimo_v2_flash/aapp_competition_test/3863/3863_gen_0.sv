module palindrome_sequence_counter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] N,
    input wire [7:0] K,
    output reg [31:0] result,
    output reg done
);

// State definitions
localparam [3:0] S_IDLE = 4'd0;
localparam [3:0] S_FIND_DIV_START = 4'd1;
localparam [3:0] S_FIND_DIV_CHECK = 4'd2;
localparam [3:0] S_FIND_DIV_STORE = 4'd3;
localparam [3:0] S_FIND_DIV_NEXT = 4'd4;
localparam [3:0] S_PREPARE = 4'd5;
localparam [3:0] S_COMPUTE_BASE_START = 4'd6;
localparam [3:0] S_COMPUTE_BASE_LOOP = 4'd7;
localparam [3:0] S_INCLUSION_EXCLUSION_START = 4'd8;
localparam [3:0] S_INCLUSION_EXCLUSION_LOOP = 4'd9;
localparam [3:0] S_INCLUSION_EXCLUSION_SUB = 4'd10;
localparam [3:0] S_CONTRIBUTION = 4'd11;
localparam [3:0] S_NEXT_DIVISOR = 4'd12;
localparam [3:0] S_DONE = 4'd13;

// Constants
localparam [31:0] MOD = 32'd1000000007;

// Internal registers
reg [3:0] state;
reg [7:0] divisors [0:31];
reg [31:0] v_values [0:31];
reg [7:0] divisor_count;
reg [7:0] i_counter;
reg [7:0] current_idx;
reg [7:0] d;
reg [31:0] base;
reg [7:0] exp;
reg [31:0] temp_v;
reg [7:0] j_counter;
reg [31:0] contrib;
reg [31:0] total_sum;
reg [7:0] k_counter;

// Helper function for modular arithmetic
function [31:0] mul_mod(input [31:0] a, input [31:0] b);
    reg [63:0] temp;
begin
    temp = a * b;
    mul_mod = temp % MOD;
end
endfunction

function [31:0] add_mod(input [31:0] a, input [31:0] b);
begin
    add_mod = (a + b) % MOD;
end
endfunction

function [31:0] sub_mod(input [31:0] a, input [31:0] b);
begin
    sub_mod = (a + MOD - b) % MOD;
end
endfunction

// Main state machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= S_IDLE;
        done <= 1'b0;
        result <= 32'd0;
        divisor_count <= 8'd0;
        total_sum <= 32'd0;
        i_counter <= 8'd0;
        current_idx <= 8'd0;
        d <= 8'd0;
        base <= 32'd0;
        exp <= 8'd0;
        temp_v <= 32'd0;
        j_counter <= 8'd0;
        contrib <= 32'd0;
        k_counter <= 8'd0;
    end else begin
        case (state)
            S_IDLE: begin
                done <= 1'b0;
                if (start) begin
                    state <= S_FIND_DIV_START;
                    i_counter <= 8'd1;
                    divisor_count <= 8'd0;
                    total_sum <= 32'd0;
                end
            end

            S_FIND_DIV_START: begin
                state <= S_FIND_DIV_CHECK;
            end

            S_FIND_DIV_CHECK: begin
                if (i_counter > N) begin
                    state <= S_PREPARE;
                    current_idx <= 8'd0;
                end else begin
                    if ((N % i_counter) == 8'd0) begin
                        state <= S_FIND_DIV_STORE;
                    end else begin
                        state <= S_FIND_DIV_NEXT;
                    end
                end
            end

            S_FIND_DIV_STORE: begin
                divisors[divisor_count] <= i_counter;
                divisor_count <= divisor_count + 8'd1;
                state <= S_FIND_DIV_NEXT;
            end

            S_FIND_DIV_NEXT: begin
                i_counter <= i_counter + 8'd1;
                state <= S_FIND_DIV_CHECK;
            end

            S_PREPARE: begin
                if (current_idx >= divisor_count) begin
                    state <= S_DONE;
                end else begin
                    d <= divisors[current_idx];
                    exp <= (divisors[current_idx] + 8'd1) >> 1;
                    state <= S_COMPUTE_BASE_START;
                end
            end

            S_COMPUTE_BASE_START: begin
                // Compute K^exp mod MOD
                base <= 32'd1;
                k_counter <= 8'd0;
                state <= S_COMPUTE_BASE_LOOP;
            end

            S_COMPUTE_BASE_LOOP: begin
                if (k_counter >= exp) begin
                    temp_v <= base;
                    j_counter <= 8'd0;
                    state <= S_INCLUSION_EXCLUSION_START;
                end else begin
                    base <= mul_mod(base, {24'd0, K});
                    k_counter <= k_counter + 8'd1;
                end
            end

            S_INCLUSION_EXCLUSION_START: begin
                if (j_counter >= current_idx) begin
                    state <= S_CONTRIBUTION;
                end else begin
                    if ((d % divisors[j_counter]) == 8'd0) begin
                        temp_v <= sub_mod(temp_v, v_values[j_counter]);
                    end
                    state <= S_INCLUSION_EXCLUSION_SUB;
                end
            end

            S_INCLUSION_EXCLUSION_SUB: begin
                j_counter <= j_counter + 8'd1;
                state <= S_INCLUSION_EXCLUSION_START;
            end

            S_CONTRIBUTION: begin
                v_values[current_idx] <= temp_v;
                if (d[0]) begin
                    contrib <= mul_mod(temp_v, {24'd0, d});
                end else begin
                    contrib <= mul_mod(temp_v, {24'd0, d >> 1});
                end
                state <= S_NEXT_DIVISOR;
            end

            S_NEXT_DIVISOR: begin
                total_sum <= add_mod(total_sum, contrib);
                current_idx <= current_idx + 8'd1;
                state <= S_PREPARE;
            end

            S_DONE: begin
                result <= total_sum;
                done <= 1'b1;
                state <= S_IDLE;
            end

            default: state <= S_IDLE;
        endcase
    end
end

endmodule