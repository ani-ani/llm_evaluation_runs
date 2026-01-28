module heap_subset_finder (
    input clk,
    input rst_n,
    input start,
    input [7:0] valid_mask,
    input [7:0] v0, v1, v2, v3, v4, v5, v6, v7,
    input [2:0] p0, p1, p2, p3, p4, p5, p6, p7,
    output reg [3:0] result,
    output reg done
);

    // Parameters
    localparam N = 8;
    localparam V_WIDTH = 8;
    localparam P_WIDTH = 3;

    // State definitions
    localparam [4:0] S_IDLE          = 5'd0;
    localparam [4:0] S_LOAD          = 5'd1;
    localparam [4:0] S_ANC_START     = 5'd2;
    localparam [4:0] S_ANC_SET       = 5'd3;
    localparam [4:0] S_ANC_NEXT_J    = 5'd4;
    localparam [4:0] S_CHECK_INIT    = 5'd5;
    localparam [4:0] S_CHECK_SUBSET  = 5'd6;
    localparam [4:0] S_CHECK_VALIDATE = 5'd7;
    localparam [4:0] S_CHECK_I_LOOP  = 5'd8;
    localparam [4:0] S_CHECK_J_LOOP  = 5'd9;
    localparam [4:0] S_CHECK_POPCOUNT = 5'd10;
    localparam [4:0] S_POPCOUNT_LOOP = 5'd11;
    localparam [4:0] S_CHECK_UPDATE  = 5'd12;
    localparam [4:0] S_CHECK_NEXT_SUBSET = 5'd13;
    localparam [4:0] S_DONE          = 5'd14;

    // Registers for inputs
    reg [V_WIDTH-1:0] v_reg [0:N-1];
    reg [P_WIDTH-1:0] p_reg [0:N-1];
    reg [N-1:0] valid_mask_reg;

    // Ancestor matrix
    reg [N-1:0] anc [0:N-1];

    // State and counters
    reg [4:0] state;
    reg [3:0] j_idx;
    reg [3:0] k_idx;
    reg [3:0] i_idx;
    reg [3:0] j_idx2;
    reg [N-1:0] subset;
    reg [3:0] max_size;
    reg invalid_flag;
    reg [3:0] popcnt;
    reg [3:0] bit_idx;

    // Helper signals for combinational logic
    wire [N-1:0] v_bit [0:N-1];
    wire [N-1:0] p_bit [0:N-1];
    genvar gi;
    generate
        for (gi = 0; gi < N; gi = gi + 1) begin : gen_helper_bits
            assign v_bit[gi] = v_reg[gi];
            assign p_bit[gi] = p_reg[gi];
        end
    endgenerate

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            done <= 1'b0;
            result <= 4'd0;
            // Initialize all arrays
            for (integer i = 0; i < N; i = i + 1) begin
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
                        done <= 1'b0;
                    end
                end

                S_LOAD: begin
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
                    for (integer i = 0; i < N; i = i + 1) begin
                        anc[i] <= 8'd0;
                    end
                    state <= S_ANC_START;
                    j_idx <= 4'd0;
                end

                S_ANC_START: begin
                    if (p_reg[j_idx] == N) begin
                        state <= S_ANC_NEXT_J;
                    end else begin
                        k_idx <= p_reg[j_idx];
                        state <= S_ANC_SET;
                    end
                end

                S_ANC_SET: begin
                    anc[k_idx][j_idx] <= 1'b1;
                    if (p_reg[k_idx] == N) begin
                        state <= S_ANC_NEXT_J;
                    end else begin
                        k_idx <= p_reg[k_idx];
                    end
                end

                S_ANC_NEXT_J: begin
                    j_idx <= j_idx + 4'd1;
                    if (j_idx + 4'd1 >= N) begin
                        state <= S_CHECK_INIT;
                    end else begin
                        state <= S_ANC_START;
                    end
                end

                S_CHECK_INIT: begin
                    max_size <= 4'd0;
                    subset <= 8'd1;
                    state <= S_CHECK_SUBSET;
                end

                S_CHECK_SUBSET: begin
                    invalid_flag <= 1'b0;
                    state <= S_CHECK_VALIDATE;
                end

                S_CHECK_VALIDATE: begin
                    if ((subset & ~valid_mask_reg) != 8'd0) begin
                        invalid_flag <= 1'b1;
                    end
                    i_idx <= 4'd0;
                    state <= S_CHECK_I_LOOP;
                end

                S_CHECK_I_LOOP: begin
                    if (i_idx >= N) begin
                        if (invalid_flag == 1'b0) begin
                            state <= S_CHECK_POPCOUNT;
                        end else begin
                            state <= S_CHECK_NEXT_SUBSET;
                        end
                    end else begin
                        if (subset[i_idx] == 1'b0) begin
                            i_idx <= i_idx + 4'd1;
                        end else begin
                            j_idx2 <= 4'd0;
                            state <= S_CHECK_J_LOOP;
                        end
                    end
                end

                S_CHECK_J_LOOP: begin
                    if (j_idx2 >= N) begin
                        i_idx <= i_idx + 4'd1;
                        state <= S_CHECK_I_LOOP;
                    end else begin
                        if (subset[j_idx2] == 1'b0 || j_idx2 == i_idx) begin
                            j_idx2 <= j_idx2 + 4'd1;
                        end else begin
                            if (anc[i_idx][j_idx2] == 1'b1 && v_reg[i_idx] <= v_reg[j_idx2]) begin
                                invalid_flag <= 1'b1;
                                state <= S_CHECK_NEXT_SUBSET;
                            end else begin
                                j_idx2 <= j_idx2 + 4'd1;
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
                    if (bit_idx >= N) begin
                        state <= S_CHECK_UPDATE;
                    end else begin
                        if (subset[bit_idx] == 1'b1) begin
                            popcnt <= popcnt + 4'd1;
                        end
                        bit_idx <= bit_idx + 4'd1;
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
                    if (subset + 8'd1 == 8'd0) begin
                        state <= S_DONE;
                    end else begin
                        state <= S_CHECK_SUBSET;
                    end
                end

                S_DONE: begin
                    done <= 1'b1;
                    result <= max_size;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule