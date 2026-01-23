module heap_subset_finder (
    input clk,
    input rst_n,
    input start,
    input [7:0] valid_mask,  // bit i = 1 if node i is valid
    input [7:0] v0, v1, v2, v3, v4, v5, v6, v7,
    input [2:0] p0, p1, p2, p3, p4, p5, p6, p7,
    output [3:0] result,
    output done
);

// Parameters
parameter N = 8;
parameter V_WIDTH = 8;
parameter P_WIDTH = 3;

// State definitions
localparam [3:0] S_IDLE = 4'd0;
localparam [3:0] S_LOAD = 4'd1;
localparam [3:0] S_ANC_START = 4'd2;
localparam [3:0] S_ANC_SET = 4'd3;
localparam [3:0] S_ANC_NEXT_J = 4'd4;
localparam [3:0] S_CHECK_INIT = 4'd5;
localparam [3:0] S_CHECK_SUBSET = 4'd6;
localparam [3:0] S_CHECK_VALIDATE = 4'd7;
localparam [3:0] S_CHECK_I_LOOP = 4'd8;
localparam [3:0] S_CHECK_J_LOOP = 4'd9;
localparam [3:0] S_CHECK_POPCOUNT = 4'd10;
localparam [3:0] S_POPCOUNT_LOOP = 4'd11;
localparam [3:0] S_CHECK_UPDATE = 4'd12;
localparam [3:0] S_CHECK_NEXT_SUBSET = 4'd13;
localparam [3:0] S_DONE = 4'd14;

// Registers for inputs
reg [V_WIDTH-1:0] v_reg [0:N-1];
reg [P_WIDTH-1:0] p_reg [0:N-1];
reg [N-1:0] valid_mask_reg;

// Ancestor matrix: anc[i] is a bitmask of nodes for which i is a proper ancestor
reg [N-1:0] anc [0:N-1];

// State and counters
reg [3:0] state;
reg [3:0] j_idx;      // index for ancestor computation
reg [3:0] k_idx;      // current ancestor node
reg [3:0] i_idx;      // outer index for subset checking
reg [3:0] j_idx2;     // inner index for subset checking
reg [N-1:0] subset;   // current subset mask
reg [3:0] max_size;   // best size found
reg invalid_flag;     // set if current subset is invalid
reg [3:0] popcnt;     // popcount of subset
reg [3:0] bit_idx;    // index for popcount loop

// Output registers
reg [3:0] result_reg;
reg done_reg;

// Helper: individual bits of subset (combinational)
wire [N-1:0] subset_bit [0:N-1];
generate
    genvar gi;
    for (gi = 0; gi < N; gi = gi + 1) begin : gen_subset_bits
        assign subset_bit[gi] = subset[gi];
    end
endgenerate

// Assign outputs
assign result = result_reg;
assign done = done_reg;

// Sequential logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= S_IDLE;
        done_reg <= 1'b0;
        result_reg <= 4'd0;
        // Clear arrays
        integer i;
        for (i = 0; i < N; i = i + 1) begin
            v_reg[i] <= 8'd0;
            p_reg[i] <= 3'd0;
            anc[i] <= 8'd0;
        end
        valid_mask_reg <= 8'd0;
        subset <= 8'd0;
        max_size <= 4'd0;
        invalid_flag <= 1'b0;
        popcnt <= 4'd0;
        bit_idx <= 4'd0;
        j_idx <= 4'd0;
        k_idx <= 4'd0;
        i_idx <= 4'd0;
        j_idx2 <= 4'd0;
    end else begin
        case (state)
            S_IDLE: begin
                if (start) begin
                    state <= S_LOAD;
                    done_reg <= 1'b0;
                end
            end

            S_LOAD: begin
                // Capture inputs
                v_reg[0] <= v0;
                v_reg[1] <= v1;
                v_reg[2] <= v2;
                v_reg[3] <= v3;
                v_reg[4] <= v4;
                v_reg[5] <= v5;
                v_reg[6] <= v6;
                v_reg[7] <= v7;
                p_reg[0] <= p0;
                p_reg[1] <= p1;
                p_reg[2] <= p2;
                p_reg[3] <= p3;
                p_reg[4] <= p4;
                p_reg[5] <= p5;
                p_reg[6] <= p6;
                p_reg[7] <= p7;
                valid_mask_reg <= valid_mask;
                // Initialize ancestor matrix
                for (i = 0; i < N; i = i + 1) begin
                    anc[i] <= 8'd0;
                end
                state <= S_ANC_START;
                j_idx <= 4'd0;
            end

            S_ANC_START: begin
                // Get first ancestor of node j_idx
                if (p_reg[j_idx] == 3'd7) begin
                    // No ancestors, skip
                    state <= S_ANC_NEXT_J;
                end else begin
                    k_idx <= p_reg[j_idx];
                    state <= S_ANC_SET;
                end
            end

            S_ANC_SET: begin
                // Mark anc[k_idx][j_idx] = 1
                anc[k_idx][j_idx] <= 1'b1;
                // Move to next ancestor
                if (p_reg[k_idx] == 3'd7) begin
                    state <= S_ANC_NEXT_J;
                end else begin
                    k_idx <= p_reg[k_idx];
                    // stay in S_ANC_SET
                end
            end

            S_ANC_NEXT_J: begin
                j_idx <= j_idx + 4'd1;
                if (j_idx >= 4'd8) begin
                    state <= S_CHECK_INIT;
                end else begin
                    state <= S_ANC_START;
                end
            end

            S_CHECK_INIT: begin
                max_size <= 4'd0;
                subset <= 8'd1; // start with subset {0}
                state <= S_CHECK_SUBSET;
            end

            S_CHECK_SUBSET: begin
                invalid_flag <= 1'b0;
                state <= S_CHECK_VALIDATE;
            end

            S_CHECK_VALIDATE: begin
                // Check if subset contains any invalid node (bit set for node not in valid_mask_reg)
                if ((subset & ~valid_mask_reg) != 8'd0) begin
                    invalid_flag <= 1'b1;
                end
                // Regardless of result, proceed to loops (if invalid, loops will be skipped later)
                i_idx <= 4'd0;
                state <= S_CHECK_I_LOOP;
            end

            S_CHECK_I_LOOP: begin
                if (i_idx >= 4'd8) begin
                    // Finished all i
                    if (invalid_flag == 1'b0) begin
                        state <= S_CHECK_POPCOUNT;
                    end else begin
                        state <= S_CHECK_NEXT_SUBSET;
                    end
                end else begin
                    if (subset_bit[i_idx] == 1'b0) begin
                        i_idx <= i_idx + 4'd1;
                        // stay in S_CHECK_I_LOOP
                    end else begin
                        j_idx2 <= 4'd0;
                        state <= S_CHECK_J_LOOP;
                    end
                end
            end

            S_CHECK_J_LOOP: begin
                if (j_idx2 >= 4'd8) begin
                    // Finished j loop for current i, move to next i
                    i_idx <= i_idx + 4'd1;
                    state <= S_CHECK_I_LOOP;
                end else begin
                    if (subset_bit[j_idx2] == 1'b0 || j_idx2 == i_idx) begin
                        j_idx2 <= j_idx2 + 4'd1;
                        // stay in S_CHECK_J_LOOP
                    end else begin
                        // Check ancestor and value
                        if (anc[i_idx][j_idx2] == 1'b1 && v_reg[i_idx] <= v_reg[j_idx2]) begin
                            invalid_flag <= 1'b1;
                            state <= S_CHECK_NEXT_SUBSET; // break loops
                        end else begin
                            j_idx2 <= j_idx2 + 4'd1;
                            // stay in S_CHECK_J_LOOP
                        end
                    end
                end
            end

            S_CHECK_POPCOUNT: begin
                popcnt <= 4'd0;
                bit_idx <= 4'd0;
                state <= S_POPCOUNT_LOOP;
            end

            S_POPCOUNT_LOOP: begin
                if (bit_idx >= 4'd8) begin
                    state <= S_CHECK_UPDATE;
                end else begin
                    if (subset_bit[bit_idx] == 1'b1) begin
                        popcnt <= popcnt + 4'd1;
                    end
                    bit_idx <= bit_idx + 4'd1;
                    // stay in S_POPCOUNT_LOOP
                end
            end

            S_CHECK_UPDATE: begin
                if (popcnt > max_size) begin
                    max_size <= popcnt;
                end
                state <= S_CHECK_NEXT_SUBSET;
            end

            S_CHECK_NEXT_SUBSET: begin
                subset <= subset + 8'd1;
                if (subset == 8'd0) begin // wrapped around to 0
                    state <= S_DONE;
                end else begin
                    state <= S_CHECK_SUBSET;
                end
            end

            S_DONE: begin
                done_reg <= 1'b1;
                result_reg <= max_size;
                // stay in done until reset
            end

            default: state <= S_IDLE;
        endcase
    end
end

endmodule