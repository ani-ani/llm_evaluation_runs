module arcaea_diversity(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [3:0] k,
    input wire [7:0] g_0, g_1, g_2, g_3,
    input wire [7:0] p_0, p_1, p_2, p_3,
    input wire [7:0] ga_0, ga_1, ga_2, ga_3,
    input wire [7:0] pa_0, pa_1, pa_2, pa_3,
    output reg [3:0] result,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE           = 4'd0;
    localparam [3:0] CAPTURE        = 4'd1;
    localparam [3:0] AWAKENABLE     = 4'd2;
    localparam [3:0] PREPARE_B      = 4'd3;
    localparam [3:0] BUILD_P        = 4'd4;
    localparam [3:0] CHECK_ANTICHAIN = 4'd5;
    localparam [3:0] NEXT_S         = 4'd6;
    localparam [3:0] NEXT_B         = 4'd7;
    localparam [3:0] FINISH         = 4'd8;

    reg [3:0] state, next_state;
    reg [3:0] cycle_counter;
    localparam [3:0] MAX_CYCLES = 4'd12; // Prevent infinite loops

    // Internal registers for inputs
    reg [3:0] n_reg, k_reg;
    reg [7:0] g [0:3];
    reg [7:0] p [0:3];
    reg [7:0] ga [0:3];
    reg [7:0] pa [0:3];
    reg awakenable [0:3];

    // Subset iteration
    reg [3:0] b_mask; // Bitmask for partners to awaken
    reg [3:0] awakenable_count;
    reg [3:0] awakenable_mask; // Mask of awakenable partners
    reg [3:0] b_count; // Current size of B

    // Build P state
    reg [7:0] p_frag [0:3];
    reg [7:0] p_step [0:3];
    reg [3:0] s_mask; // Subsets of P
    reg [3:0] s_count;
    reg is_valid_antichain;
    reg [3:0] temp_max_div;
    reg [3:0] current_max_div;
    reg [3:0] subset_size;
    integer i, j, idx_i, idx_j;

    // FSM State Registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            cycle_counter <= 4'd0;
            n_reg <= 4'd0;
            k_reg <= 4'd0;
            for (i = 0; i < 4; i = i + 1) begin
                g[i] <= 8'd0;
                p[i] <= 8'd0;
                ga[i] <= 8'd0;
                pa[i] <= 8'd0;
                awakenable[i] <= 1'b0;
                p_frag[i] <= 8'd0;
                p_step[i] <= 8'd0;
            end
            awakenable_count <= 4'd0;
            awakenable_mask <= 4'd0;
            b_mask <= 4'd0;
            b_count <= 4'd0;
            s_mask <= 4'd0;
            s_count <= 4'd0;
            temp_max_div <= 4'd0;
            current_max_div <= 4'd0;
            is_valid_antichain <= 1'b0;
            subset_size <= 4'd0;
        end else begin
            state <= next_state;

            if (start) begin
                cycle_counter <= 4'd0;
                n_reg <= n;
                k_reg <= k;
                g[0] <= g_0; g[1] <= g_1; g[2] <= g_2; g[3] <= g_3;
                p[0] <= p_0; p[1] <= p_1; p[2] <= p_2; p[3] <= p_3;
                ga[0] <= ga_0; ga[1] <= ga_1; ga[2] <= ga_2; ga[3] <= ga_3;
                pa[0] <= pa_0; pa[1] <= pa_1; pa[2] <= pa_2; pa[3] <= pa_3;
                current_max_div <= 4'd0;
                awakenable_mask <= 4'd0;
                awakenable_count <= 4'd0;
            end

            case (state)
                CAPTURE: begin
                    // Determine awakenable partners
                    awakenable[0] <= ((ga[0] != 8'd0) || (pa[0] != 8'd0)) && (n_reg > 4'd0);
                    awakenable[1] <= ((ga[1] != 8'd0) || (pa[1] != 8'd0)) && (n_reg > 4'd1);
                    awakenable[2] <= ((ga[2] != 8'd0) || (pa[2] != 8'd0)) && (n_reg > 4'd2);
                    awakenable[3] <= ((ga[3] != 8'd0) || (pa[3] != 8'd0)) && (n_reg > 4'd3);
                    awakenable_mask <= 4'd0;
                    awakenable_count <= 4'd0;
                    if (n_reg > 4'd0) begin
                        if (ga[0] != 8'd0 || pa[0] != 8'd0) awakenable_mask[0] <= 1'b1;
                        if (ga[0] != 8'd0 || pa[0] != 8'd0) awakenable_count <= awakenable_count + 4'd1;
                    end
                    if (n_reg > 4'd1) begin
                        if (ga[1] != 8'd0 || pa[1] != 8'd0) awakenable_mask[1] <= 1'b1;
                        if (ga[1] != 8'd0 || pa[1] != 8'd0) awakenable_count <= awakenable_count + 4'd1;
                    end
                    if (n_reg > 4'd2) begin
                        if (ga[2] != 8'd0 || pa[2] != 8'd0) awakenable_mask[2] <= 1'b1;
                        if (ga[2] != 8'd0 || pa[2] != 8'd0) awakenable_count <= awakenable_count + 4'd1;
                    end
                    if (n_reg > 4'd3) begin
                        if (ga[3] != 8'd0 || pa[3] != 8'd0) awakenable_mask[3] <= 1'b1;
                        if (ga[3] != 8'd0 || pa[3] != 8'd0) awakenable_count <= awakenable_count + 4'd1;
                    end
                end

                PREPARE_B: begin
                    b_mask <= 4'd0;
                    b_count <= 4'd0;
                    temp_max_div <= 4'd0;
                end

                BUILD_P: begin
                    // Build P based on b_mask
                    for (idx_i = 0; idx_i < 4; idx_i = idx_i + 1) begin
                        if (idx_i < n_reg) begin
                            if (b_mask[idx_i] && awakenable[idx_i]) begin
                                p_frag[idx_i] <= ga[idx_i];
                                p_step[idx_i] <= pa[idx_i];
                            end else begin
                                p_frag[idx_i] <= g[idx_i];
                                p_step[idx_i] <= p[idx_i];
                            end
                        end else begin
                            p_frag[idx_i] <= 8'd0;
                            p_step[idx_i] <= 8'd0;
                        end
                    end
                    s_mask <= 4'd0;
                    s_count <= 4'd0;
                    is_valid_antichain <= 1'b1;
                    subset_size <= 4'd0;
                end

                CHECK_ANTICHAIN: begin
                    // Check if s_mask is a valid antichain
                    // Count bits in s_mask
                    subset_size <= 4'd0;
                    for (idx_i = 0; idx_i < 4; idx_i = idx_i + 1) begin
                        if (idx_i < n_reg && s_mask[idx_i]) begin
                            subset_size <= subset_size + 4'd1;
                        end
                    end

                    is_valid_antichain <= 1'b1;
                    for (idx_i = 0; idx_i < 4; idx_i = idx_i + 1) begin
                        for (idx_j = 0; idx_j < 4; idx_j = idx_j + 1) begin
                            if (idx_i < n_reg && idx_j < n_reg && idx_i != idx_j) begin
                                if (s_mask[idx_i] && s_mask[idx_j]) begin
                                    if ((p_frag[idx_i] > p_frag[idx_j] && p_step[idx_i] > p_step[idx_j]) ||
                                        (p_frag[idx_i] < p_frag[idx_j] && p_step[idx_i] < p_step[idx_j])) begin
                                        is_valid_antichain <= 1'b0;
                                    end
                                end
                            end
                        end
                    end
                end

                NEXT_S: begin
                    if (is_valid_antichain && subset_size > temp_max_div) begin
                        temp_max_div <= subset_size;
                    end
                end

                NEXT_B: begin
                    if (temp_max_div > current_max_div) begin
                        current_max_div <= temp_max_div;
                    end
                end

                FINISH: begin
                    result <= current_max_div;
                    done <= 1'b1;
                end
            endcase

            if (state != IDLE && state != FINISH) begin
                cycle_counter <= cycle_counter + 4'd1;
            end

            if (state == FINISH) begin
                done <= 1'b1;
            end else begin
                done <= 1'b0;
            end
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = CAPTURE;
            end

            CAPTURE: begin
                if (cycle_counter >= 4'd1) next_state = PREPARE_B;
            end

            PREPARE_B: begin
                if (cycle_counter >= 4'd2) next_state = BUILD_P;
            end

            BUILD_P: begin
                if (cycle_counter >= 4'd3) next_state = CHECK_ANTICHAIN;
            end

            CHECK_ANTICHAIN: begin
                if (cycle_counter >= 4'd4) next_state = NEXT_S;
            end

            NEXT_S: begin
                // Check if we have iterated through all subsets of P
                // Generate next subset mask
                if (s_mask < (1 << n_reg) - 1) begin
                    // Simple increment to next mask (only checks first n bits)
                    next_state = BUILD_P; // Go back to build P for next S
                    if (cycle_counter >= 4'd11) next_state = IDLE; // Safety timeout
                end else begin
                    next_state = NEXT_B;
                end
            end

            NEXT_B: begin
                // Check if we have iterated through all valid B
                // Generate next B mask
                if (b_mask < (1 << n_reg) - 1) begin
                    next_state = BUILD_P; // Go back to build P for next B
                end else begin
                    next_state = FINISH;
                end
            end

            FINISH: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule