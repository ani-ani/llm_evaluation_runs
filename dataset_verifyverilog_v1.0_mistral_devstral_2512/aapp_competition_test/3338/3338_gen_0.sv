module arcaea_diversity(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [3:0] k,
    input [7:0] g_0, g_1, g_2, g_3,
    input [7:0] p_0, p_1, p_2, p_3,
    input [7:0] ga_0, ga_1, ga_2, ga_3,
    input [7:0] pa_0, pa_1, pa_2, pa_3,
    output reg [3:0] result,
    output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CAPTURE = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] FINISH = 2'd3;

    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    reg [3:0] n_reg;
    reg [3:0] k_reg;
    reg [7:0] g_reg [0:3];
    reg [7:0] p_reg [0:3];
    reg [7:0] ga_reg [0:3];
    reg [7:0] pa_reg [0:3];

    reg [3:0] awakenable_count;
    reg [3:0] awakenable_mask;
    reg [3:0] current_subset;
    reg [3:0] subset_size;
    reg [3:0] current_partner;
    reg [3:0] current_bitmask;
    reg [3:0] current_max_size;
    reg [3:0] global_max;

    reg [3:0] i, j;
    reg valid_antichain;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            n_reg <= 4'd0;
            k_reg <= 4'd0;
            for (i = 0; i < 4; i = i + 1) begin
                g_reg[i] <= 8'd0;
                p_reg[i] <= 8'd0;
                ga_reg[i] <= 8'd0;
                pa_reg[i] <= 8'd0;
            end
            awakenable_count <= 4'd0;
            awakenable_mask <= 4'd0;
            current_subset <= 4'd0;
            subset_size <= 4'd0;
            current_partner <= 4'd0;
            current_bitmask <= 4'd0;
            current_max_size <= 4'd0;
            global_max <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= CAPTURE;
                    end
                end

                CAPTURE: begin
                    n_reg <= n;
                    k_reg <= k;
                    g_reg[0] <= g_0; g_reg[1] <= g_1; g_reg[2] <= g_2; g_reg[3] <= g_3;
                    p_reg[0] <= p_0; p_reg[1] <= p_1; p_reg[2] <= p_2; p_reg[3] <= p_3;
                    ga_reg[0] <= ga_0; ga_reg[1] <= ga_1; ga_reg[2] <= ga_2; ga_reg[3] <= ga_3;
                    pa_reg[0] <= pa_0; pa_reg[1] <= pa_1; pa_reg[2] <= pa_2; pa_reg[3] <= pa_3;

                    awakenable_count <= 4'd0;
                    awakenable_mask <= 4'd0;
                    for (i = 0; i < n_reg; i = i + 1) begin
                        if (ga_reg[i] != 8'd0 || pa_reg[i] != 8'd0) begin
                            awakenable_mask[i] <= 1'b1;
                            awakenable_count <= awakenable_count + 4'd1;
                        end else begin
                            awakenable_mask[i] <= 1'b0;
                        end
                    end

                    current_subset <= 4'd0;
                    subset_size <= 4'd0;
                    current_partner <= 4'd0;
                    current_bitmask <= 4'd0;
                    current_max_size <= 4'd0;
                    global_max <= 4'd0;

                    state <= COMPUTE;
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;

                    if (current_subset < (1 << awakenable_count)) begin
                        subset_size <= 4'd0;
                        for (i = 0; i < awakenable_count; i = i + 1) begin
                            if (current_subset[i]) begin
                                subset_size <= subset_size + 4'd1;
                            end
                        end

                        if (subset_size <= k_reg) begin
                            current_max_size <= 4'd0;
                            for (current_bitmask = 0; current_bitmask < (1 << n_reg); current_bitmask = current_bitmask + 1) begin
                                valid_antichain <= 1'b1;
                                for (i = 0; i < n_reg; i = i + 1) begin
                                    if (current_bitmask[i]) begin
                                        for (j = i + 1; j < n_reg; j = j + 1) begin
                                            if (current_bitmask[j]) begin
                                                reg [7:0] frag_i, step_i, frag_j, step_j;
                                                if (awakenable_mask[i] && current_subset[awakenable_mask[i]]) begin
                                                    frag_i <= ga_reg[i];
                                                    step_i <= pa_reg[i];
                                                end else begin
                                                    frag_i <= g_reg[i];
                                                    step_i <= p_reg[i];
                                                end
                                                if (awakenable_mask[j] && current_subset[awakenable_mask[j]]) begin
                                                    frag_j <= ga_reg[j];
                                                    step_j <= pa_reg[j];
                                                end else begin
                                                    frag_j <= g_reg[j];
                                                    step_j <= p_reg[j];
                                                end
                                                if ((frag_i > frag_j && step_i > step_j) || (frag_i < frag_j && step_i < step_j)) begin
                                                    valid_antichain <= 1'b0;
                                                end
                                            end
                                        end
                                    end
                                end
                                if (valid_antichain) begin
                                    reg [3:0] size;
                                    size <= 4'd0;
                                    for (i = 0; i < n_reg; i = i + 1) begin
                                        if (current_bitmask[i]) begin
                                            size <= size + 4'd1;
                                        end
                                    end
                                    if (size > current_max_size) begin
                                        current_max_size <= size;
                                    end
                                end
                            end
                            if (current_max_size > global_max) begin
                                global_max <= current_max_size;
                            end
                        end
                        current_subset <= current_subset + 4'd1;
                    end else begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    result <= global_max;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule