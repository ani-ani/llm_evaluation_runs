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
reg [31:0] e_i [0:7];      // E[a_i]
reg [31:0] e2_i [0:7];     // E[a_i^2]
reg [31:0] e_ij_0 [0:7];   // e_ij for i=0
reg [31:0] e_ij_1 [0:7];   // e_ij for i=1
reg [31:0] e_ij_2 [0:7];   // e_ij for i=2
reg [31:0] e_ij_3 [0:7];   // e_ij for i=3
reg [31:0] e_ij_4 [0:7];   // e_ij for i=4
reg [31:0] e_ij_5 [0:7];   // e_ij for i=5
reg [31:0] e_ij_6 [0:7];   // e_ij for i=6
reg [31:0] e_ij_7 [0:7];   // e_ij for i=7

// Combinational signals
wire [3:0] L;
wire [31:0] inv_L;
reg [31:0] p_i [0:7];     // probability for each box
wire [31:0] next_e_i_0, next_e_i_1, next_e_i_2, next_e_i_3;
wire [31:0] next_e_i_4, next_e_i_5, next_e_i_6, next_e_i_7;
wire [31:0] next_e2_i_0, next_e2_i_1, next_e2_i_2, next_e2_i_3;
wire [31:0] next_e2_i_4, next_e2_i_5, next_e2_i_6, next_e2_i_7;
wire [31:0] next_e_ij_0 [0:7];
wire [31:0] next_e_ij_1 [0:7];
wire [31:0] next_e_ij_2 [0:7];
wire [31:0] next_e_ij_3 [0:7];
wire [31:0] next_e_ij_4 [0:7];
wire [31:0] next_e_ij_5 [0:7];
wire [31:0] next_e_ij_6 [0:7];
wire [31:0] next_e_ij_7 [0:7];
wire [31:0] sum_e2_i;

// State machine
reg [1:0] state;
localparam [1:0] IDLE = 2'd0;
localparam [1:0] UPDATE = 2'd1;
localparam [1:0] OUTPUT = 2'd2;
localparam [1:0] FINISH = 2'd3;

// Compute L = v - u + 1
assign L = v - u + 1;

// Lookup inv_L based on L
always @(*) begin
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
always @(*) begin
    integer i;
    for (i = 0; i < 8; i = i + 1) begin
        p_i[i] = ((i+1) >= u && (i+1) <= v) ? inv_L : 32'd0;
    end
end

// Compute next_e_i for each index
assign next_e_i_0 = (e_i[0] + p_i[0]) % MOD;
assign next_e_i_1 = (e_i[1] + p_i[1]) % MOD;
assign next_e_i_2 = (e_i[2] + p_i[2]) % MOD;
assign next_e_i_3 = (e_i[3] + p_i[3]) % MOD;
assign next_e_i_4 = (e_i[4] + p_i[4]) % MOD;
assign next_e_i_5 = (e_i[5] + p_i[5]) % MOD;
assign next_e_i_6 = (e_i[6] + p_i[6]) % MOD;
assign next_e_i_7 = (e_i[7] + p_i[7]) % MOD;

// Compute next_e2_i for each index
wire [63:0] prod_0, prod_1, prod_2, prod_3, prod_4, prod_5, prod_6, prod_7;
wire [63:0] term_0, term_1, term_2, term_3, term_4, term_5, term_6, term_7;
assign prod_0 = p_i[0] * e_i[0]; assign term_0 = (prod_0 << 1);
assign prod_1 = p_i[1] * e_i[1]; assign term_1 = (prod_1 << 1);
assign prod_2 = p_i[2] * e_i[2]; assign term_2 = (prod_2 << 1);
assign prod_3 = p_i[3] * e_i[3]; assign term_3 = (prod_3 << 1);
assign prod_4 = p_i[4] * e_i[4]; assign term_4 = (prod_4 << 1);
assign prod_5 = p_i[5] * e_i[5]; assign term_5 = (prod_5 << 1);
assign prod_6 = p_i[6] * e_i[6]; assign term_6 = (prod_6 << 1);
assign prod_7 = p_i[7] * e_i[7]; assign term_7 = (prod_7 << 1);
assign next_e2_i_0 = (e2_i[0] + term_0 + p_i[0]) % MOD;
assign next_e2_i_1 = (e2_i[1] + term_1 + p_i[1]) % MOD;
assign next_e2_i_2 = (e2_i[2] + term_2 + p_i[2]) % MOD;
assign next_e2_i_3 = (e2_i[3] + term_3 + p_i[3]) % MOD;
assign next_e2_i_4 = (e2_i[4] + term_4 + p_i[4]) % MOD;
assign next_e2_i_5 = (e2_i[5] + term_5 + p_i[5]) % MOD;
assign next_e2_i_6 = (e2_i[6] + term_6 + p_i[6]) % MOD;
assign next_e2_i_7 = (e2_i[7] + term_7 + p_i[7]) % MOD;

// Compute next_e_ij for i != j
wire [63:0] term1_0_0, term2_0_0;
wire [63:0] term1_0_1, term2_0_1;
// ... (expand for all i,j)
// For brevity, computing only for valid pairs
assign term1_0_1 = p_i[1] * e_i[0];
assign term2_0_1 = p_i[0] * e_i[1];
assign next_e_ij_0[1] = (e_ij_0[1] + term1_0_1 + term2_0_1) % MOD;

assign term1_0_2 = p_i[2] * e_i[0];
assign term2_0_2 = p_i[0] * e_i[2];
assign next_e_ij_0[2] = (e_ij_0[2] + term1_0_2 + term2_0_2) % MOD;

assign term1_0_3 = p_i[3] * e_i[0];
assign term2_0_3 = p_i[0] * e_i[3];
assign next_e_ij_0[3] = (e_ij_0[3] + term1_0_3 + term2_0_3) % MOD;

assign term1_0_4 = p_i[4] * e_i[0];
assign term2_0_4 = p_i[0] * e_i[4];
assign next_e_ij_0[4] = (e_ij_0[4] + term1_0_4 + term2_0_4) % MOD;

assign term1_0_5 = p_i[5] * e_i[0];
assign term2_0_5 = p_i[0] * e_i[5];
assign next_e_ij_0[5] = (e_ij_0[5] + term1_0_5 + term2_0_5) % MOD;

assign term1_0_6 = p_i[6] * e_i[0];
assign term2_0_6 = p_i[0] * e_i[6];
assign next_e_ij_0[6] = (e_ij_0[6] + term1_0_6 + term2_0_6) % MOD;

assign term1_0_7 = p_i[7] * e_i[0];
assign term2_0_7 = p_i[0] * e_i[7];
assign next_e_ij_0[7] = (e_ij_0[7] + term1_0_7 + term2_0_7) % MOD;

// For i=0, j=0 (diagonal, unused)
assign next_e_ij_0[0] = e_ij_0[0];

// Similar patterns for other rows (abbreviated for clarity)
// In practice, this would be fully expanded or use a different approach
// For brevity, we keep the structure but note that all 8x8 pairs would be computed

// Partial implementation for other rows (i=1)
assign next_e_ij_1[0] = (e_ij_1[0] + p_i[0]*e_i[1] + p_i[1]*e_i[0]) % MOD;
assign next_e_ij_1[2] = (e_ij_1[2] + p_i[2]*e_i[1] + p_i[1]*e_i[2]) % MOD;
assign next_e_ij_1[3] = (e_ij_1[3] + p_i[3]*e_i[1] + p_i[1]*e_i[3]) % MOD;
assign next_e_ij_1[4] = (e_ij_1[4] + p_i[4]*e_i[1] + p_i[1]*e_i[4]) % MOD;
assign next_e_ij_1[5] = (e_ij_1[5] + p_i[5]*e_i[1] + p_i[1]*e_i[5]) % MOD;
assign next_e_ij_1[6] = (e_ij_1[6] + p_i[6]*e_i[1] + p_i[1]*e_i[6]) % MOD;
assign next_e_ij_1[7] = (e_ij_1[7] + p_i[7]*e_i[1] + p_i[1]*e_i[7]) % MOD;
assign next_e_ij_1[1] = e_ij_1[1];

// Additional rows (abbreviated)
assign next_e_ij_2[0] = (e_ij_2[0] + p_i[0]*e_i[2] + p_i[2]*e_i[0]) % MOD;
assign next_e_ij_2[1] = (e_ij_2[1] + p_i[1]*e_i[2] + p_i[2]*e_i[1]) % MOD;
assign next_e_ij_2[3] = (e_ij_2[3] + p_i[3]*e_i[2] + p_i[2]*e_i[3]) % MOD;
assign next_e_ij_2[4] = (e_ij_2[4] + p_i[4]*e_i[2] + p_i[2]*e_i[4]) % MOD;
assign next_e_ij_2[5] = (e_ij_2[5] + p_i[5]*e_i[2] + p_i[2]*e_i[5]) % MOD;
assign next_e_ij_2[6] = (e_ij_2[6] + p_i[6]*e_i[2] + p_i[2]*e_i[6]) % MOD;
assign next_e_ij_2[7] = (e_ij_2[7] + p_i[7]*e_i[2] + p_i[2]*e_i[7]) % MOD;
assign next_e_ij_2[2] = e_ij_2[2];

// Row 3
assign next_e_ij_3[0] = (e_ij_3[0] + p_i[0]*e_i[3] + p_i[3]*e_i[0]) % MOD;
assign next_e_ij_3[1] = (e_ij_3[1] + p_i[1]*e_i[3] + p_i[3]*e_i[1]) % MOD;
assign next_e_ij_3[2] = (e_ij_3[2] + p_i[2]*e_i[3] + p_i[3]*e_i[2]) % MOD;
assign next_e_ij_3[4] = (e_ij_3[4] + p_i[4]*e_i[3] + p_i[3]*e_i[4]) % MOD;
assign next_e_ij_3[5] = (e_ij_3[5] + p_i[5]*e_i[3] + p_i[3]*e_i[5]) % MOD;
assign next_e_ij_3[6] = (e_ij_3[6] + p_i[6]*e_i[3] + p_i[3]*e_i[6]) % MOD;
assign next_e_ij_3[7] = (e_ij_3[7] + p_i[7]*e_i[3] + p_i[3]*e_i[7]) % MOD;
assign next_e_ij_3[3] = e_ij_3[3];

// Row 4
assign next_e_ij_4[0] = (e_ij_4[0] + p_i[0]*e_i[4] + p_i[4]*e_i[0]) % MOD;
assign next_e_ij_4[1] = (e_ij_4[1] + p_i[1]*e_i[4] + p_i[4]*e_i[1]) % MOD;
assign next_e_ij_4[2] = (e_ij_4[2] + p_i[2]*e_i[4] + p_i[4]*e_i[2]) % MOD;
assign next_e_ij_4[3] = (e_ij_4[3] + p_i[3]*e_i[4] + p_i[4]*e_i[3]) % MOD;
assign next_e_ij_4[5] = (e_ij_4[5] + p_i[5]*e_i[4] + p_i[4]*e_i[5]) % MOD;
assign next_e_ij_4[6] = (e_ij_4[6] + p_i[6]*e_i[4] + p_i[4]*e_i[6]) % MOD;
assign next_e_ij_4[7] = (e_ij_4[7] + p_i[7]*e_i[4] + p_i[4]*e_i[7]) % MOD;
assign next_e_ij_4[4] = e_ij_4[4];

// Row 5
assign next_e_ij_5[0] = (e_ij_5[0] + p_i[0]*e_i[5] + p_i[5]*e_i[0]) % MOD;
assign next_e_ij_5[1] = (e_ij_5[1] + p_i[1]*e_i[5] + p_i[5]*e_i[1]) % MOD;
assign next_e_ij_5[2] = (e_ij_5[2] + p_i[2]*e_i[5] + p_i[5]*e_i[2]) % MOD;
assign next_e_ij_5[3] = (e_ij_5[3] + p_i[3]*e_i[5] + p_i[5]*e_i[3]) % MOD;
assign next_e_ij_5[4] = (e_ij_5[4] + p_i[4]*e_i[5] + p_i[5]*e_i[4]) % MOD;
assign next_e_ij_5[6] = (e_ij_5[6] + p_i[6]*e_i[5] + p_i[5]*e_i[6]) % MOD;
assign next_e_ij_5[7] = (e_ij_5[7] + p_i[7]*e_i[5] + p_i[5]*e_i[7]) % MOD;
assign next_e_ij_5[5] = e_ij_5[5];

// Row 6
assign next_e_ij_6[0] = (e_ij_6[0] + p_i[0]*e_i[6] + p_i[6]*e_i[0]) % MOD;
assign next_e_ij_6[1] = (e_ij_6[1] + p_i[1]*e_i[6] + p_i[6]*e_i[1]) % MOD;
assign next_e_ij_6[2] = (e_ij_6[2] + p_i[2]*e_i[6] + p_i[6]*e_i[2]) % MOD;
assign next_e_ij_6[3] = (e_ij_6[3] + p_i[3]*e_i[6] + p_i[6]*e_i[3]) % MOD;
assign next_e_ij_6[4] = (e_ij_6[4] + p_i[4]*e_i[6] + p_i[6]*e_i[4]) % MOD;
assign next_e_ij_6[5] = (e_ij_6[5] + p_i[5]*e_i[6] + p_i[6]*e_i[5]) % MOD;
assign next_e_ij_6[7] = (e_ij_6[7] + p_i[7]*e_i[6] + p_i[6]*e_i[7]) % MOD;
assign next_e_ij_6[6] = e_ij_6[6];

// Row 7
assign next_e_ij_7[0] = (e_ij_7[0] + p_i[0]*e_i[7] + p_i[7]*e_i[0]) % MOD;
assign next_e_ij_7[1] = (e_ij_7[1] + p_i[1]*e_i[7] + p_i[7]*e_i[1]) % MOD;
assign next_e_ij_7[2] = (e_ij_7[2] + p_i[2]*e_i[7] + p_i[7]*e_i[2]) % MOD;
assign next_e_ij_7[3] = (e_ij_7[3] + p_i[3]*e_i[7] + p_i[7]*e_i[3]) % MOD;
assign next_e_ij_7[4] = (e_ij_7[4] + p_i[4]*e_i[7] + p_i[7]*e_i[4]) % MOD;
assign next_e_ij_7[5] = (e_ij_7[5] + p_i[5]*e_i[7] + p_i[7]*e_i[5]) % MOD;
assign next_e_ij_7[6] = (e_ij_7[6] + p_i[6]*e_i[7] + p_i[7]*e_i[6]) % MOD;
assign next_e_ij_7[7] = e_ij_7[7];

// Sum of e2_i to compute E(A)
wire [31:0] sum_temp_0, sum_temp_1, sum_temp_2, sum_temp_3, sum_temp_4, sum_temp_5, sum_temp_6, sum_temp_7;
assign sum_temp_0 = 0;
assign sum_temp_1 = (sum_temp_0 + e2_i[0]) % MOD;
assign sum_temp_2 = (sum_temp_1 + e2_i[1]) % MOD;
assign sum_temp_3 = (sum_temp_2 + e2_i[2]) % MOD;
assign sum_temp_4 = (sum_temp_3 + e2_i[3]) % MOD;
assign sum_temp_5 = (sum_temp_4 + e2_i[4]) % MOD;
assign sum_temp_6 = (sum_temp_5 + e2_i[5]) % MOD;
assign sum_temp_7 = (sum_temp_6 + e2_i[6]) % MOD;
assign sum_e2_i = (sum_temp_7 + e2_i[7]) % MOD;

// Sequential logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset all state to zero
        e_i[0] <= 32'd0; e_i[1] <= 32'd0; e_i[2] <= 32'd0; e_i[3] <= 32'd0;
        e_i[4] <= 32'd0; e_i[5] <= 32'd0; e_i[6] <= 32'd0; e_i[7] <= 32'd0;
        e2_i[0] <= 32'd0; e2_i[1] <= 32'd0; e2_i[2] <= 32'd0; e2_i[3] <= 32'd0;
        e2_i[4] <= 32'd0; e2_i[5] <= 32'd0; e2_i[6] <= 32'd0; e2_i[7] <= 32'd0;
        e_ij_0[0] <= 32'd0; e_ij_0[1] <= 32'd0; e_ij_0[2] <= 32'd0; e_ij_0[3] <= 32'd0;
        e_ij_0[4] <= 32'd0; e_ij_0[5] <= 32'd0; e_ij_0[6] <= 32'd0; e_ij_0[7] <= 32'd0;
        e_ij_1[0] <= 32'd0; e_ij_1[1] <= 32'd0; e_ij_1[2] <= 32'd0; e_ij_1[3] <= 32'd0;
        e_ij_1[4] <= 32'd0; e_ij_1[5] <= 32'd0; e_ij_1[6] <= 32'd0; e_ij_1[7] <= 32'd0;
        e_ij_2[0] <= 32'd0; e_ij_2[1] <= 32'd0; e_ij_2[2] <= 32'd0; e_ij_2[3] <= 32'd0;
        e_ij_2[4] <= 32'd0; e_ij_2[5] <= 32'd0; e_ij_2[6] <= 32'd0; e_ij_2[7] <= 32'd0;
        e_ij_3[0] <= 32'd0; e_ij_3[1] <= 32'd0; e_ij_3[2] <= 32'd0; e_ij_3[3] <= 32'd0;
        e_ij_3[4] <= 32'd0; e_ij_3[5] <= 32'd0; e_ij_3[6] <= 32'd0; e_ij_3[7] <= 32'd0;
        e_ij_4[0] <= 32'd0; e_ij_4[1] <= 32'd0; e_ij_4[2] <= 32'd0; e_ij_4[3] <= 32'd0;
        e_ij_4[4] <= 32'd0; e_ij_4[5] <= 32'd0; e_ij_4[6] <= 32'd0; e_ij_4[7] <= 32'd0;
        e_ij_5[0] <= 32'd0; e_ij_5[1] <= 32'd0; e_ij_5[2] <= 32'd0; e_ij_5[3] <= 32'd0;
        e_ij_5[4] <= 32'd0; e_ij_5[5] <= 32'd0; e_ij_5[6] <= 32'd0; e_ij_5[7] <= 32'd0;
        e_ij_6[0] <= 32'd0; e_ij_6[1] <= 32'd0; e_ij_6[2] <= 32'd0; e_ij_6[3] <= 32'd0;
        e_ij_6[4] <= 32'd0; e_ij_6[5] <= 32'd0; e_ij_6[6] <= 32'd0; e_ij_6[7] <= 32'd0;
        e_ij_7[0] <= 32'd0; e_ij_7[1] <= 32'd0; e_ij_7[2] <= 32'd0; e_ij_7[3] <= 32'd0;
        e_ij_7[4] <= 32'd0; e_ij_7[5] <= 32'd0; e_ij_7[6] <= 32'd0; e_ij_7[7] <= 32'd0;
        done <= 1'b0;
        result <= 32'd0;
        state <= IDLE;
    end else begin
        done <= 1'b0; // default
        case (state)
            IDLE: begin
                if (start) begin
                    if (query_type == 1'd0) begin
                        state <= UPDATE;
                    end else if (query_type == 1'd1) begin
                        state <= OUTPUT;
                    end
                end
            end
            UPDATE: begin
                e_i[0] <= next_e_i_0; e_i[1] <= next_e_i_1; e_i[2] <= next_e_i_2; e_i[3] <= next_e_i_3;
                e_i[4] <= next_e_i_4; e_i[5] <= next_e_i_5; e_i[6] <= next_e_i_6; e_i[7] <= next_e_i_7;
                e2_i[0] <= next_e2_i_0; e2_i[1] <= next_e2_i_1; e2_i[2] <= next_e2_i_2; e2_i[3] <= next_e2_i_3;
                e2_i[4] <= next_e2_i_4; e2_i[5] <= next_e2_i_5; e2_i[6] <= next_e2_i_6; e2_i[7] <= next_e2_i_7;
                e_ij_0[0] <= next_e_ij_0[0]; e_ij_0[1] <= next_e_ij_0[1]; e_ij_0[2] <= next_e_ij_0[2]; e_ij_0[3] <= next_e_ij_0[3];
                e_ij_0[4] <= next_e_ij_0[4]; e_ij_0[5] <= next_e_ij_0[5]; e_ij_0[6] <= next_e_ij_0[6]; e_ij_0[7] <= next_e_ij_0[7];
                e_ij_1[0] <= next_e_ij_1[0]; e_ij_1[1] <= next_e_ij_1[1]; e_ij_1[2] <= next_e_ij_1[2]; e_ij_1[3] <= next_e_ij_1[3];
                e_ij_1[4] <= next_e_ij_1[4]; e_ij_1[5] <= next_e_ij_1[5]; e_ij_1[6] <= next_e_ij_1[6]; e_ij_1[7] <= next_e_ij_1[7];
                e_ij_2[0] <= next_e_ij_2[0]; e_ij_2[1] <= next_e_ij_2[1]; e_ij_2[2] <= next_e_ij_2[2]; e_ij_2[3] <= next_e_ij_2[3];
                e_ij_2[4] <= next_e_ij_2[4]; e_ij_2[5] <= next_e_ij_2[5]; e_ij_2[6] <= next_e_ij_2[6]; e_ij_2[7] <= next_e_ij_2[7];
                e_ij_3[0] <= next_e_ij_3[0]; e_ij_3[1] <= next_e_ij_3[1]; e_ij_3[2] <= next_e_ij_3[2]; e_ij_3[3] <= next_e_ij_3[3];
                e_ij_3[4] <= next_e_ij_3[4]; e_ij_3[5] <= next_e_ij_3[5]; e_ij_3[6] <= next_e_ij_3[6]; e_ij_3[7] <= next_e_ij_3[7];
                e_ij_4[0] <= next_e_ij_4[0]; e_ij_4[1] <= next_e_ij_4[1]; e_ij_4[2] <= next_e_ij_4[2]; e_ij_4[3] <= next_e_ij_4[3];
                e_ij_4[4] <= next_e_ij_4[4]; e_ij_4[5] <= next_e_ij_4[5]; e_ij_4[6] <= next_e_ij_4[6]; e_ij_4[7] <= next_e_ij_4[7];
                e_ij_5[0] <= next_e_ij_5[0]; e_ij_5[1] <= next_e_ij_5[1]; e_ij_5[2] <= next_e_ij_5[2]; e_ij_5[3] <= next_e_ij_5[3];
                e_ij_5[4] <= next_e_ij_5[4]; e_ij_5[5] <= next_e_ij_5[5]; e_ij_5[6] <= next_e_ij_5[6]; e_ij_5[7] <= next_e_ij_5[7];
                e_ij_6[0] <= next_e_ij_6[0]; e_ij_6[1] <= next_e_ij_6[1]; e_ij_6[2] <= next_e_ij_6[2]; e_ij_6[3] <= next_e_ij_6[3];
                e_ij_6[4] <= next_e_ij_6[4]; e_ij_6[5] <= next_e_ij_6[5]; e_ij_6[6] <= next_e_ij_6[6]; e_ij_6[7] <= next_e_ij_6[7];
                e_ij_7[0] <= next_e_ij_7[0]; e_ij_7[1] <= next_e_ij_7[1]; e_ij_7[2] <= next_e_ij_7[2]; e_ij_7[3] <= next_e_ij_7[3];
                e_ij_7[4] <= next_e_ij_7[4]; e_ij_7[5] <= next_e_ij_7[5]; e_ij_7[6] <= next_e_ij_7[6]; e_ij_7[7] <= next_e_ij_7[7];
                state <= FINISH;
            end
            OUTPUT: begin
                result <= sum_e2_i;
                done <= 1'b1;
                state <= IDLE;
            end
            FINISH: begin
                done <= 1'b1;
                state <= IDLE;
            end
            default: state <= IDLE;
        endcase
    end
end

endmodule