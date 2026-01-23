module restaurant_occupancy(
    input clk,
    input rst_n,
    input start,
    input [2:0] n_in,
    input [2:0] t_in,
    input [2:0] g_in,
    input [7:0] capacity_0, capacity_1, capacity_2, capacity_3,
    input [7:0] capacity_4, capacity_5, capacity_6, capacity_7,
    output reg [31:0] expected_occupancy,
    output reg done
);

    // Fixed-point constants
    localparam [15:0] ONE = 16'h10000; // 1.0 in Q16.16
    localparam [15:0] INV_G_SCALE = 16'h10000; // Placeholder for 1/g calculation

    // State encoding
    localparam IDLE = 3'b000;
    localparam SETUP_INIT = 3'b001;
    localparam INIT_HOUR = 3'b010;
    localparam CLEAR_DST = 3'b011;
    localparam PROCESS_SOURCE = 3'b100;
    localparam PROCESS_GROUP = 3'b101;
    localparam NEXT_SOURCE = 3'b110;
    localparam SUM_RESULT = 3'b111;
    localparam SUM_LOOP = 4'b1000;
    localparam DONE = 4'b1001;

    reg [3:0] state, next_state;

    // Inputs stored in registers
    reg [2:0] n, t, g;
    reg [7:0] caps [0:7];

    // DP Memory: 256 states x (Prob(32b) + Exp(32b))
    // Width: 64 bits. Prob high 32, Exp low 32.
    // Prob is Q16.16 (stored in upper bits)
    // Exp is Q16.16
    reg [63:0] memA [0:255];
    reg [63:0] memB [0:255];
    reg src_is_A;

    // Iteration counters
    reg [3:0] current_hour; // 0 to t
    reg [7:0] state_idx;    // 0 to 2^n - 1
    reg [3:0] group_size;   // 1 to g
    reg [7:0] search_idx;   // table index for finding smallest table
    reg [7:0] search_limit; // 2^n - 1

    // Intermediate calculations
    reg [31:0] current_prob; // Q16.16
    reg [31:0] current_exp;  // Q16.16
    reg [31:0] temp_prob;    // Q16.16
    reg [31:0] temp_exp;     // Q16.16
    reg [31:0] temp_inv_g;   // Q16.16
    reg [31:0] temp_mult;    // Q32.32 intermediate
    reg [31:0] found_idx;    // index of table found, or 255 if none
    reg        table_found;  // flag
    reg [7:0]  new_state;    // state after placing group
    reg        is_occupied;  // check if bit is set in state_idx
    reg [31:0] group_size_fp; // group size in Q16.16
    reg [31:0] people_added_fp; // group size added to exp
    reg        need_writeback; // flag to trigger state update

    // Loop control
    integer i;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Main FSM
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = SETUP_INIT;
                else next_state = IDLE;
            end
            SETUP_INIT: begin
                next_state = INIT_HOUR;
            end
            INIT_HOUR: begin
                if (current_hour > t) next_state = SUM_RESULT;
                else next_state = CLEAR_DST;
            end
            CLEAR_DST: begin
                if (state_idx < 256) next_state = CLEAR_DST;
                else next_state = PROCESS_SOURCE;
            end
            PROCESS_SOURCE: begin
                if (current_prob == 0) next_state = NEXT_SOURCE;
                else next_state = PROCESS_GROUP;
            end
            PROCESS_GROUP: begin
                if (group_size > g) next_state = NEXT_SOURCE;
                else next_state = PROCESS_GROUP;
            end
            NEXT_SOURCE: begin
                if (state_idx >= search_limit) next_state = INIT_HOUR;
                else next_state = PROCESS_SOURCE;
            end
            SUM_RESULT: begin
                next_state = SUM_LOOP;
            end
            SUM_LOOP: begin
                if (state_idx < search_limit) next_state = SUM_LOOP;
                else next_state = DONE;
            end
            DONE: begin
                next_state = DONE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            expected_occupancy <= 0;
            done <= 0;
            current_hour <= 0;
            state_idx <= 0;
            group_size <= 1;
            search_idx <= 0;
            need_writeback <= 0;
            // Reset memory
            for (i = 0; i < 256; i = i + 1) begin
                memA[i] <= 0;
                memB[i] <= 0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        // Latch inputs
                        n <= n_in;
                        t <= t_in;
                        g <= g_in;
                        caps[0] <= capacity_0;
                        caps[1] <= capacity_1;
                        caps[2] <= capacity_2;
                        caps[3] <= capacity_3;
                        caps[4] <= capacity_4;
                        caps[5] <= capacity_5;
                        caps[6] <= capacity_6;
                        caps[7] <= capacity_7;
                        // Initialize control vars
                        search_limit <= (1 << n_in) - 1; // Max state index
                        // Calculate inv_g_fp
                        case (g_in)
                            3'd2: inv_g_fp <= 32'h00008000; // 1/2 = 0.5 (32768)
                            3'd3: inv_g_fp <= 32'h00005555; // 1/3 approx (21845)
                            3'd4: inv_g_fp <= 32'h00004000; // 1/4 = 0.25 (16384)
                            3'd5: inv_g_fp <= 32'h00003333; // 1/5 (13107)
                            3'd6: inv_g_fp <= 32'h00002AAB; // 1/6 (10923)
                            3'd7: inv_g_fp <= 32'h00002492; // 1/7 (9362)
                            3'd8: inv_g_fp <= 32'h00002000; // 1/8 = 0.125 (8192)
                            default: inv_g_fp <= 32'h00010000; // 1.0
                        endcase
                    end
                end

                SETUP_INIT: begin
                    if (state_idx == 0) begin
                        memA[0] <= 64'h00010000_00000000; // Prob 1.0, Exp 0
                        memB[0] <= 0;
                    end else begin
                        memA[state_idx] <= 0;
                        memB[state_idx] <= 0;
                    end
                    state_idx <= state_idx + 1;
                    if (state_idx < 256) next_state = SETUP_INIT;
                    else begin
                        current_hour <= 0;
                        state_idx <= 0;
                        next_state = INIT_HOUR;
                    end
                end

                INIT_HOUR: begin
                    current_hour <= current_hour + 1;
                    src_is_A <= !src_is_A;
                    if (current_hour > t) next_state = SUM_RESULT;
                    else next_state = CLEAR_DST;
                end

                CLEAR_DST: begin
                    if (src_is_A) memB[state_idx] <= 0;
                    else memA[state_idx] <= 0;
                    state_idx <= state_idx + 1;
                    if (state_idx < 256) next_state = CLEAR_DST;
                    else begin
                        state_idx <= 0;
                        next_state = PROCESS_SOURCE;
                    end
                end

                PROCESS_SOURCE: begin
                    if (src_is_A) begin
                        current_prob <= memA[state_idx][63:32];
                        current_exp <= memA[state_idx][31:0];
                    end else begin
                        current_prob <= memB[state_idx][63:32];
                        current_exp <= memB[state_idx][31:0];
                    end
                    group_size <= 1;
                    if (current_prob == 0) next_state = NEXT_SOURCE;
                    else next_state = PROCESS_GROUP;
                end

                PROCESS_GROUP: begin
                    // Calculate new_state, prob_contrib, exp_contrib
                    // Use combinational logic for table finding
                    // Then: dp_next[new_state] <= dp_next[new_state] + {prob_contrib, exp_contrib};
                    group_size <= group_size + 1;
                    if (group_size <= g) next_state = PROCESS_GROUP;
                    else next_state = NEXT_SOURCE;
                end

                NEXT_SOURCE: begin
                    state_idx <= state_idx + 1;
                    if (state_idx < search_limit) next_state = PROCESS_SOURCE;
                    else next_state = INIT_HOUR;
                end

                SUM_RESULT: begin
                    expected_occupancy <= 0;
                    state_idx <= 0;
                    next_state = SUM_LOOP;
                end

                SUM_LOOP: begin
                    if (src_is_A) expected_occupancy <= expected_occupancy + memA[state_idx][31:0];
                    else expected_occupancy <= expected_occupancy + memB[state_idx][31:0];
                    state_idx <= state_idx + 1;
                    if (state_idx < search_limit) next_state = SUM_LOOP;
                    else next_state = DONE;
                end

                DONE: begin
                    done <= 1;
                end

                default: next_state = IDLE;
            endcase
        end
    end

    // Combinational logic for new_state and contributions
    wire [63:0] full_mult_1 = current_prob * inv_g_fp;
    wire [31:0] prob_contrib_comb = full_mult_1[47:16];
    wire [63:0] full_mult_2 = current_exp * inv_g_fp;
    wire [31:0] term1_comb = full_mult_2[47:16];
    wire [31:0] term2_comb = prob_contrib_comb * group_size;
    wire [31:0] exp_contrib_comb = term1_comb + term2_comb;
    wire [7:0] new_state_comb;

    always @(*) begin
        new_state_comb = state_idx;
        for (int i = 0; i < n; i = i + 1) begin
            if (i < n && !state_idx[i] && caps[i] >= group_size) begin
                new_state_comb = state_idx | (1 << i);
                break;
            end
        end
    end

    // Update dp_next in PROCESS_GROUP
    always @(posedge clk) begin
        if (state == PROCESS_GROUP) begin
            if (src_is_A) memB[new_state_comb] <= memB[new_state_comb] + {prob_contrib_comb, exp_contrib_comb};
            else memA[new_state_comb] <= memA[new_state_comb] + {prob_contrib_comb, exp_contrib_comb};
        end
    end

endmodule
