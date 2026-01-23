module PokenomGo (
    input clk,
    input rst_n,
    input start,
    input query_type,
    input [3:0] u,
    input [3:0] v,
    output reg [31:0] result,
    output reg done
);

// Parameters
parameter MOD = 1000000007;
parameter N = 8;

// Internal state
reg [31:0] e_i [0:N-1];      // E[a_i]
reg [31:0] e2_i [0:N-1];     // E[a_i^2]
reg [31:0] e_ij [0:N-1][0:N-1]; // E[a_i a_j] for i != j

// Combinational signals
wire [3:0] L;
wire [31:0] inv_L;
wire [31:0] p_i [0:N-1];     // probability for each box
wire [31:0] next_e_i [0:N-1];
wire [31:0] next_e2_i [0:N-1];
wire [31:0] next_e_ij [0:N-1][0:N-1];
wire [31:0] sum_e2_i;

// Compute L = v - u + 1
assign L = v - u + 1;

// Lookup inv_L based on L (precomputed modular inverses for L=1..8)
always @* begin
    case(L)
        4'd1: inv_L = 32'd1;
        4'd2: inv_L = 32'd500000004;
        4'd3: inv_L = 32'd333333336;
        4'd4: inv_L = 32'd250000002;
        4'd5: inv_L = 32'd400000003;
        4'd6: inv_L = 32'd166666668;
        4'd7: inv_L = 32'd142857144;
        4'd8: inv_L = 32'd125000001;
        default: inv_L = 32'd0;
    endcase
end

// Generate p_i for each box (convert 1-indexed input to 0-indexed)
integer i, j;
for (i = 0; i < N; i = i + 1) begin
    assign p_i[i] = ((i+1) >= u && (i+1) <= v) ? inv_L : 32'd0;
end

// Compute next_e_i
// new_e_i = e_i + p_i (mod MOD)
for (i = 0; i < N; i = i + 1) begin
    assign next_e_i[i] = (e_i[i] + p_i[i]) % MOD;
end

// Compute next_e2_i
// new_e2_i = e2_i + 2 * p_i * e_i + p_i (mod MOD)
for (i = 0; i < N; i = i + 1) begin
    wire [63:0] prod = p_i[i] * e_i[i];
    wire [63:0] term = (prod << 1); // 2 * p_i * e_i
    assign next_e2_i[i] = (e2_i[i] + term + p_i[i]) % MOD;
end

// Compute next_e_ij for i != j
// new_e_ij = e_ij + p_j * e_i + p_i * e_j (mod MOD)
for (i = 0; i < N; i = i + 1) begin
    for (j = 0; j < N; j = j + 1) begin
        if (i != j) begin
            wire [63:0] term1 = p_i[j] * e_i[i];
            wire [63:0] term2 = p_i[i] * e_i[j];
            assign next_e_ij[i][j] = (e_ij[i][j] + term1 + term2) % MOD;
        end else begin
            assign next_e_ij[i][j] = e_ij[i][j]; // diagonal unused
        end
    end
end

// Sum of e2_i to compute E(A)
wire [31:0] sum_temp [0:N];
assign sum_temp[0] = 0;
for (i = 0; i < N; i = i + 1) begin
    assign sum_temp[i+1] = (sum_temp[i] + e2_i[i]) % MOD;
end
assign sum_e2_i = sum_temp[N];

// Sequential logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset all state to zero
        for (i = 0; i < N; i = i + 1) begin
            e_i[i] <= 0;
            e2_i[i] <= 0;
            for (j = 0; j < N; j = j + 1) begin
                e_ij[i][j] <= 0;
            end
        end
        done <= 0;
        result <= 0;
    end else begin
        done <= 0; // default
        if (start) begin
            if (query_type == 0) begin
                // Type 1: update state
                for (i = 0; i < N; i = i + 1) begin
                    e_i[i] <= next_e_i[i];
                    e2_i[i] <= next_e2_i[i];
                    for (j = 0; j < N; j = j + 1) begin
                        e_ij[i][j] <= next_e_ij[i][j];
                    end
                end
            end else if (query_type == 1) begin
                // Type 2: output E(A)
                result <= sum_e2_i;
                done <= 1;
            end
        end
    end
end

endmodule