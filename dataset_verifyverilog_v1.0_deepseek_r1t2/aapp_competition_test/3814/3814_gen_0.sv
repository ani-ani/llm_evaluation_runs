module ramen_count(
    input clk,
    input rst_n,
    input start,
    input [9:0] N,
    input [31:0] M,
    output reg [31:0] result,
    output reg done
);
    // State declarations
    localparam [3:0] IDLE             = 4'd0;
    localparam [3:0] COMPUTE_COMB     = 4'd1;
    localparam [3:0] COMPUTE_BASE     = 4'd2;
    localparam [3:0] COMPUTE_TERM1    = 4'd3;
    localparam [3:0] INIT_STIRLING    = 4'd4;
    localparam [3:0] COMPUTE_STIRLING = 4'd5;
    localparam [3:0] SUM_TERM2        = 4'd6;
    localparam [3:0] COMPUTE_FK       = 4'd7;
    localparam [3:0] UPDATE_ANS       = 4'd8;
    localparam [3:0] NEXT_K           = 4'd9;
    localparam [3:0] FINISHED         = 4'd10;

    reg [3:0] state;
    reg [9:0] k;
    reg [9:0] m;
    reg [31:0] comb;
    reg [31:0] base;
    reg [31:0] term1;
    reg [31:0] term2;
    reg [31:0] Fk;
    reg [31:0] acc;
    reg [31:0] sign;
    reg [31:0] stirling [0:1001];
    reg [31:0] temp_stir [0:1001];
    
    integer i;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Modular exponentiation function (simplified)
    function [31:0] pow_mod;
        input [31:0] base_in;
        input [31:0] exp_in;
        input [31:0] mod_in;
        reg [31:0] result_int;
        integer j;
        begin
            result_int = 32'd1;
            for (j = 0; j < exp_in; j = j + 1) begin
                result_int = (result_int * base_in) % mod_in;
            end
            pow_mod = result_int;
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            k <= 10'd0;
            m <= 10'd0;
            comb <= 32'd0;
            base <= 32'd0;
            term1 <= 32'd0;
            term2 <= 32'd0;
            Fk <= 32'd0;
            acc <= 32'd0;
            sign <= 32'd0;
            cycle_count <= 8'd0;
            for (i = 0; i <= 1001; i = i + 1) begin
                stirling[i] <= 32'd0;
            end
        end
        else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    acc <= 32'd0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        k <= 10'd0;
                        state <= COMPUTE_COMB;
                    end
                end
                
                COMPUTE_COMB: begin
                    if (k == 10'd0) comb <= 32'd1;
                    else comb <= comb * (N - k + 10'd1) / k;
                    state <= COMPUTE_BASE;
                end
                
                COMPUTE_BASE: begin
                    base <= pow_mod(32'd2, (N - k), M);
                    state <= COMPUTE_TERM1;
                end
                
                COMPUTE_TERM1: begin
                    term1 <= pow_mod(32'd2, base, M);
                    state <= INIT_STIRLING;
                    m <= 10'd0;
                end
                
                INIT_STIRLING: begin
                    for (i = 0; i <= 1001; i = i + 1) begin
                        stirling[i] <= (i == 0) ? 32'd1 : 32'd0;
                    end
                    state <= COMPUTE_STIRLING;
                    m <= 10'd1;
                end
                
                COMPUTE_STIRLING: begin
                    if (m <= (k + 10'd1)) begin
                        temp_stir[0] <= (m == 10'd1) ? 32'd1 : 32'd0;
                        for (i = 1; i <= (k + 10'd1); i = i + 1) begin
                            temp_stir[i] <= (stirling[i] * i) + stirling[i-1];
                        end
                        for (i = 0; i <= 1001; i = i + 1) begin
                            stirling[i] <= temp_stir[i];
                        end
                        m <= m + 10'd1;
                    end
                    else begin
                        m <= 10'd0;
                        term2 <= 32'd0;
                        state <= SUM_TERM2;
                    end
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES) state <= FINISHED;
                end
                
                SUM_TERM2: begin
                    if (m <= k) begin
                        term2 <= (term2 + (pow_mod(base, m, M) * stirling[m+10'd1])) % M;
                        m <= m + 10'd1;
                    end
                    else begin
                        state <= COMPUTE_FK;
                    end
                end
                
                COMPUTE_FK: begin
                    Fk <= (term1 * term2) % M;
                    state <= UPDATE_ANS;
                end
                
                UPDATE_ANS: begin
                    if (k[0] == 1'b0) acc <= (acc + (comb * Fk) % M) % M;
                    else acc <= (acc + M - (comb * Fk) % M) % M;
                    state <= NEXT_K;
                end
                
                NEXT_K: begin
                    if (k < N) begin
                        k <= k + 10'd1;
                        state <= COMPUTE_COMB;
                    end
                    else begin
                        state <= FINISHED;
                    end
                end
                
                FINISHED: begin
                    result <= acc;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule