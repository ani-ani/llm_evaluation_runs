module bus_time_calculator (
    input wire clk,
    input wire rst_n,
    input wire start,
    
    // All values in Q16.16 fixed-point format
    input wire [31:0] n,   // Number of pupils (integer part only)
    input wire [31:0] l,   // Distance
    input wire [31:0] v1,  // Walking speed
    input wire [31:0] v2,  // Bus speed
    input wire [31:0] k,   // Bus capacity (integer part only)
    
    output reg [31:0] time,
    output reg done
);

// Internal state
reg [3:0] state;
reg [4:0] iter;
reg [31:0] m, L, R, M, S, T, T_mult, S_mult;
reg [63:0] mult_temp;

// Fixed-point multiplication (Q16.16 * Q16.16)
function [31:0] q_mul;
    input [31:0] a, b;
    begin
        mult_temp = a * b;
        q_mul = mult_temp[47:16];
    end
endfunction

localparam [3:0] IDLE  = 4'd0;
localparam [3:0] INIT  = 4'd1;
localparam [3:0] LOOP  = 4'd2;
localparam [3:0] CALC  = 4'd3;
localparam [3:0] UPDATE = 4'd4;
localparam [3:0] DONE  = 4'd5;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        time <= 32'd0;
        m <= 32'd0;
        L <= 32'd0;
        R <= 32'd0;
        M <= 32'd0;
        S <= 32'd0;
        T <= 32'd0;
        T_mult <= 32'd0;
        S_mult <= 32'd0;
        iter <= 5'd0;
        mult_temp <= 64'd0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    state <= INIT;
                end
            end
            
            INIT: begin
                // m = ceil(n/k) = (n + k - 1) / k
                m <= (n + k - 32'd1) / k;
                L <= 32'd0;
                R <= l;
                iter <= 5'd0;
                state <= LOOP;
            end
            
            LOOP: begin
                if (iter >= 5'd16) begin
                    time <= M;
                    state <= DONE;
                end else begin
                    // M = (L + R) / 2
                    M <= (L + R) >> 1;
                    state <= CALC;
                end
            end
            
            CALC: begin
                // S = l - M
                S <= l - M;
                // T = M * (2*m - 1) - l
                // First compute 2*m - 1
                T <= q_mul(M, (m << 1) - 32'd1) - l;
                state <= UPDATE;
            end
            
            UPDATE: begin
                // Compare T*v1 with S*v2
                // T*v1 > S*v2 ? R = M : L = M
                T_mult <= q_mul(T, v1);
                S_mult <= q_mul(S, v2);
                state <= UPDATE + 1;
            end
            
            UPDATE + 1: begin
                if (T_mult > S_mult) begin
                    R <= M;
                end else begin
                    L <= M;
                end
                iter <= iter + 5'd1;
                state <= LOOP;
            end
            
            DONE: begin
                done <= 1'b1;
                state <= IDLE;
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule