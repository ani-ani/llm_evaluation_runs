module art_dealer_count (
    input clk,
    input rst_n,
    input start,
    input [7:0] client_idx,
    input [7:0] a_in,
    input [7:0] b_in,
    output reg [15:0] result,
    output reg done,
    output reg error
);

localparam N = 8;
localparam MOD = 10007;

reg [7:0] a_vals[N];
reg [7:0] b_vals[N];
reg [2:0] state;
reg [7:0] load_count;

function [15:0] mod;
input [15:0] x;
begin
    mod = x - (x / MOD) * MOD;
endfunction

assign prod_ab = 1;
generate
    for (int i=0; i<N; i++) begin: loop
        prod_ab = mod(prod_ab * (a_vals[i] + b_vals[i]));
    end
endgenerate

assign prod_b = 1;
generate
    for (int i=0; i<N; i++) begin: loop
        prod_b = mod(prod_b * b_vals[i]);
    end
endgenerate

assign sum_a_prod_b = 0;
generate
    for (int i=0; i<N; i++) begin: loop
        wire [15:0] term;
        term = a_vals[i];
        wire [15:0] temp_b = 1;
        for (int j=0; j<N; j++) begin: inner_loop
            if (j != i) begin
                temp_b = mod(temp_b * b_vals[j]);
            end
        end
        term = mod(term * temp_b);
        sum_a_prod_b = mod(sum_a_prod_b + term);
    end
endgenerate

assign temp = prod_ab - prod_b - sum_a_prod_b;
assign final_result = mod(temp + MOD);

always @(posedge clk) begin
    if (!rst_n) begin
        state <= 3'd0;
        load_count <= 8'd0;
        for (int i=0; i<N; i++) begin
            a_vals[i] <= 8'd0;
            b_vals[i] <= 8'd0;
        end
        result <= 16'd0;
        done <= 1'b0;
        error <= 1'b0;
    end else begin
        if (start) begin
            if (state == 3'd0) begin
                state <= 3'd1;
                load_count <= 8'd0;
            end
        end
        case (state)
            3'd1: begin
                if (load_count < N) begin
                    a_vals[load_count] <= a_in;
                    b_vals[load_count] <= b_in;
                    load_count <= load_count + 1;
                end else begin
                    state <= 3'd2;
                end
            end
            3'd2: begin
                result <= final_result;
                done <= 1'b1;
                state <= 3'd3;
            end
            3'd3: begin
                state <= 3'd3;
            end
            default: state <= 3'd0;
        endcase
    end
end
