module sheldon_counter (input clk, input rst_n, input start, input [63:0] range_start, input [63:0] range_end, output reg [31:0] count, output reg done);
reg [4:0] n_cnt;
reg [4:0] m_cnt;
reg [5:0] k_cnt;
reg [31:0] total_count;
reg [63:0] max_k_val;

function automatic integer compute_value;
input int N, M, k;
endfunction

function automatic integer compute_max_k;
input int N, M;
endfunction

function automatic integer compute_value(N, M, k);
input int N, M, k;
localparam integer MAX_K = 32;
integer value, len, block_val, i;
value = (1 << N) - 1;
len = N;
for (i=0; i<MAX_K; i++) begin
if (i < k) begin
block_val = ((1 << N) -1) << M;
value = (block_val << len) | value;
len = len + N + M;
end
end
return value;
endfunction

function automatic integer compute_max_k(N, M);
input int N, M;
integer denom = N + M;
return (64 - N) / denom;
endfunction

always_ff @(posedge clk) begin
if (!rst_n) begin
n_cnt <= 1;
m_cnt <= 1;
k_cnt <= 1;
total_count <= 0;
done <= 0;
max_k_val <= compute_max_k(1, 1);
end
else begin
if (start && !done) begin
if (n_cnt != 1 || m_cnt != 1) begin
max_k_val <= compute_max_k(n_cnt, m_cnt);
end
integer current_max_k = max_k_val;
if (k_cnt <= current_max_k) begin
integer val = compute_value(n_cnt, m_cnt, k_cnt);
if (val >= range_start && val <= range_end) begin
total_count <= total_count + 1;
end
k_cnt <= k_cnt + 1;
end
else begin
if (m_cnt < 16) begin
m_cnt <= m_cnt + 1;
k_cnt <= 1;
max_k_val <= compute_max_k(n_cnt, m_cnt);
end
else if (n_cnt < 16) begin
n_cnt <= n_cnt + 1;
m_cnt <= 1;
k_cnt <= 1;
max_k_val <= compute_max_k(n_cnt, m_cnt);
end
else begin
done <= 1;
end
end
end
end
end

assign count = total_count;
assign done = done;
endmodule