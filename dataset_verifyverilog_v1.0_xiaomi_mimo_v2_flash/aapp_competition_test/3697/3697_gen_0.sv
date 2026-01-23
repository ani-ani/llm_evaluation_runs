module election_solver (
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [2:0] k,
    input [4:0] m,
    input [4:0] a,
    input [4:0] vote_count_0,
    input [4:0] vote_count_1,
    input [4:0] vote_count_2,
    input [4:0] vote_count_3,
    input [4:0] vote_count_4,
    input [4:0] vote_count_5,
    input [4:0] vote_count_6,
    input [4:0] vote_count_7,
    input [4:0] last_vote_0,
    input [4:0] last_vote_1,
    input [4:0] last_vote_2,
    input [4:0] last_vote_3,
    input [4:0] last_vote_4,
    input [4:0] last_vote_5,
    input [4:0] last_vote_6,
    input [4:0] last_vote_7,
    output reg [1:0] result_0,
    output reg [1:0] result_1,
    output reg [1:0] result_2,
    output reg [1:0] result_3,
    output reg [1:0] result_4,
    output reg [1:0] result_5,
    output reg [1:0] result_6,
    output reg [1:0] result_7,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    reg [1:0] state;
    reg [3:0] i_idx;
    reg [3:0] j_idx;
    reg [3:0] k_idx;
    reg [3:0] p_idx;
    reg [3:0] q_idx;
    reg [3:0] s_idx;
    reg [3:0] idx;
    reg [4:0] costs_0;
    reg [4:0] costs_1;
    reg [4:0] costs_2;
    reg [4:0] costs_3;
    reg [4:0] costs_4;
    reg [4:0] costs_5;
    reg [4:0] costs_6;
    reg [4:0] total_cost;
    reg [4:0] R;
    reg [4:0] count;
    reg [4:0] need1;
    reg [4:0] need2;
    reg [4:0] temp_cost;
    reg [4:0] vote_i;
    reg [4:0] vote_j;
    reg [4:0] last_i;
    reg [4:0] last_j;
    reg [4:0] m_minus_a;
    reg [4:0] calc_result;
    reg [4:0] v_i_plus_R;
    reg [4:0] v_j_gt_v_i_plus_R;
    reg [4:0] v_j_eq_v_i_plus_R;
    reg [4:0] last_j_lt_m_minus_1;
    reg [4:0] v_j_gt_v_i;
    reg [4:0] v_j_eq_v_i;
    reg [4:0] last_j_lt_last_i;
    reg [4:0] v_i_minus_v_j;
    reg [4:0] v_i_minus_v_j_eq_1;
    reg [4:0] last_i_gt_a;
    reg [4:0] need1_lt_need2;
    reg [4:0] total_cost_gt_R;
    reg [4:0] v_i_plus_R_eq_0;
    reg [4:0] count_lt_k;
    reg [4:0] cycle_count;
    localparam [4:0] MAX_CYCLES = 5'd20;

    // Input array indexing
    always @(*) begin
        case (i_idx)
            4'd0: vote_i = vote_count_0;
            4'd1: vote_i = vote_count_1;
            4'd2: vote_i = vote_count_2;
            4'd3: vote_i = vote_count_3;
            4'd4: vote_i = vote_count_4;
            4'd5: vote_i = vote_count_5;
            4'd6: vote_i = vote_count_6;
            4'd7: vote_i = vote_count_7;
            default: vote_i = 5'd0;
        endcase
        case (j_idx)
            4'd0: vote_j = vote_count_0;
            4'd1: vote_j = vote_count_1;
            4'd2: vote_j = vote_count_2;
            4'd3: vote_j = vote_count_3;
            4'd4: vote_j = vote_count_4;
            4'd5: vote_j = vote_count_5;
            4'd6: vote_j = vote_count_6;
            4'd7: vote_j = vote_count_7;
            default: vote_j = 5'd0;
        endcase
        case (i_idx)
            4'd0: last_i = last_vote_0;
            4'd1: last_i = last_vote_1;
            4'd2: last_i = last_vote_2;
            4'd3: last_i = last_vote_3;
            4'd4: last_i = last_vote_4;
            4'd5: last_i = last_vote_5;
            4'd6: last_i = last_vote_6;
            4'd7: last_i = last_vote_7;
            default: last_i = 5'd0;
        endcase
        case (j_idx)
            4'd0: last_j = last_vote_0;
            4'd1: last_j = last_vote_1;
            4'd2: last_j = last_vote_2;
            4'd3: last_j = last_vote_3;
            4'd4: last_j = last_vote_4;
            4'd5: last_j = last_vote_5;
            4'd6: last_j = last_vote_6;
            4'd7: last_j = last_vote_7;
            default: last_j = 5'd0;
        endcase
    end

    // Computation logic
    always @(*) begin
        m_minus_a = m - a;
        R = m_minus_a;
        v_i_plus_R = vote_i + R;
        v_i_plus_R_eq_0 = (v_i_plus_R == 5'd0) ? 5'd1 : 5'd0;

        // cost computation for j != i
        v_j_gt_v_i = (vote_j > vote_i) ? 5'd1 : 5'd0;
        v_j_eq_v_i = (vote_j == vote_i) ? 5'd1 : 5'd0;
        last_j_lt_last_i = (last_j < last_i) ? 5'd1 : 5'd0;
        v_i_minus_v_j = vote_i - vote_j;
        v_i_minus_v_j_eq_1 = (v_i_minus_v_j == 5'd1) ? 5'd1 : 5'd0;
        last_i_gt_a = (last_i > a) ? 5'd1 : 5'd0;
        
        // need1 calculation
        need1 = v_i_minus_v_j + 5'd1;
        // need2 calculation
        if (v_i_minus_v_j_eq_1 && last_i_gt_a)
            need2 = 5'd1;
        else
            need2 = need1;
        
        need1_lt_need2 = (need1 < need2) ? 5'd1 : 5'd0;
        
        if (v_j_gt_v_i)
            calc_result = 5'd0;
        else if (v_j_eq_v_i) begin
            if (last_j_lt_last_i)
                calc_result = 5'd0;
            else
                calc_result = 5'd1;
        end else begin
            if (need1_lt_need2)
                calc_result = need1;
            else
                calc_result = need2;
        end

        // cost array update
        case (idx)
            4'd0: begin
                if (idx < 4'd7)
                    costs_0 = calc_result;
            end
            4'd1: costs_1 = calc_result;
            4'd2: costs_2 = calc_result;
            4'd3: costs_3 = calc_result;
            4'd4: costs_4 = calc_result;
            4'd5: costs_5 = calc_result;
            4'd6: costs_6 = calc_result;
        endcase

        // sort exchange
        case (p_idx)
            4'd0: begin
                case (q_idx)
                    4'd0: temp_cost = costs_0;
                    4'd1: temp_cost = costs_1;
                    4'd2: temp_cost = costs_2;
                    4'd3: temp_cost = costs_3;
                    4'd4: temp_cost = costs_4;
                    4'd5: temp_cost = costs_5;
                    4'd6: temp_cost = costs_6;
                    default: temp_cost = 5'd0;
                endcase
                if (q_idx < 4'd6) begin
                    case (q_idx)
                        4'd0: begin
                            if (costs_0 > costs_1) begin
                                costs_0 = costs_1;
                                costs_1 = temp_cost;
                            end
                        end
                        4'd1: begin
                            if (costs_1 > costs_2) begin
                                costs_1 = costs_2;
                                costs_2 = temp_cost;
                            end
                        end
                        4'd2: begin
                            if (costs_2 > costs_3) begin
                                costs_2 = costs_3;
                                costs_3 = temp_cost;
                            end
                        end
                        4'd3: begin
                            if (costs_3 > costs_4) begin
                                costs_3 = costs_4;
                                costs_4 = temp_cost;
                            end
                        end
                        4'd4: begin
                            if (costs_4 > costs_5) begin
                                costs_4 = costs_5;
                                costs_5 = temp_cost;
                            end
                        end
                        4'd5: begin
                            if (costs_5 > costs_6) begin
                                costs_5 = costs_6;
                                costs_6 = temp_cost;
                            end
                        end
                    endcase
                end
            end
        endcase

        // total cost sum
        if (s_idx < k) begin
            case (s_idx)
                4'd0: total_cost = costs_0;
                4'd1: total_cost = costs_0 + costs_1;
                4'd2: total_cost = costs_0 + costs_1 + costs_2;
                4'd3: total_cost = costs_0 + costs_1 + costs_2 + costs_3;
                4'd4: total_cost = costs_0 + costs_1 + costs_2 + costs_3 + costs_4;
                4'd5: total_cost = costs_0 + costs_1 + costs_2 + costs_3 + costs_4 + costs_5;
                4'd6: total_cost = costs_0 + costs_1 + costs_2 + costs_3 + costs_4 + costs_5 + costs_6;
                default: total_cost = costs_0;
            endcase
        end else begin
            total_cost = costs_0 + costs_1 + costs_2 + costs_3 + costs_4 + costs_5 + costs_6;
        end
        
        total_cost_gt_R = (total_cost > R) ? 5'd1 : 5'd0;

        // final comparison
        v_j_gt_v_i_plus_R = (vote_j > v_i_plus_R) ? 5'd1 : 5'd0;
        v_j_eq_v_i_plus_R = (vote_j == v_i_plus_R) ? 5'd1 : 5'd0;
        last_j_lt_m_minus_1 = (last_j < (m - 5'd1)) ? 5'd1 : 5'd0;
    end

    // Output array assignments
    always @(*) begin
        case (i_idx)
            4'd0: result_0 = calc_result[1:0];
            4'd1: result_1 = calc_result[1:0];
            4'd2: result_2 = calc_result[1:0];
            4'd3: result_3 = calc_result[1:0];
            4'd4: result_4 = calc_result[1:0];
            4'd5: result_5 = calc_result[1:0];
            4'd6: result_6 = calc_result[1:0];
            4'd7: result_7 = calc_result[1:0];
        endcase
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            i_idx <= 4'd0;
            j_idx <= 4'd0;
            k_idx <= 4'd0;
            p_idx <= 4'd0;
            q_idx <= 4'd0;
            s_idx <= 4'd0;
            idx <= 4'd0;
            costs_0 <= 5'd0;
            costs_1 <= 5'd0;
            costs_2 <= 5'd0;
            costs_3 <= 5'd0;
            costs_4 <= 5'd0;
            costs_5 <= 5'd0;
            costs_6 <= 5'd0;
            count <= 5'd0;
            calc_result <= 5'd0;
            result_0 <= 2'd0;
            result_1 <= 2'd0;
            result_2 <= 2'd0;
            result_3 <= 2'd0;
            result_4 <= 2'd0;
            result_5 <= 2'd0;
            result_6 <= 2'd0;
            result_7 <= 2'd0;
            cycle_count <= 5'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 5'd0;
                    i_idx <= 4'd0;
                    j_idx <= 4'd0;
                    k_idx <= 4'd0;
                    p_idx <= 4'd0;
                    q_idx <= 4'd0;
                    s_idx <= 4'd0;
                    idx <= 4'd0;
                    if (start) begin
                        state <= COMPUTE;
                        if (n == 3'd0) begin
                            state <= FINISH;
                        end
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 5'd1;
                    
                    if (i_idx < n) begin
                        // Step 1: Collect costs for candidate i
                        if (j_idx < n) begin
                            if (j_idx != i_idx) begin
                                idx <= idx + 4'd1;
                            end
                            j_idx <= j_idx + 4'd1;
                        end else if (idx > 4'd0) begin
                            // Step 2: Sort costs
                            if (p_idx < idx - 4'd1) begin
                                if (q_idx < idx - 4'd1 - p_idx) begin
                                    q_idx <= q_idx + 4'd1;
                                end else begin
                                    p_idx <= p_idx + 4'd1;
                                    q_idx <= 4'd0;
                                end
                            end else if (s_idx < k) begin
                                // Step 3: Sum top k costs
                                s_idx <= s_idx + 4'd1;
                            end else begin
                                // Step 4: Determine result
                                if (total_cost_gt_R) begin
                                    calc_result <= 4'd1; // TIE
                                end else begin
                                    // Check for 0 votes
                                    if (v_i_plus_R_eq_0) begin
                                        calc_result <= 4'd3; // IMPOSSIBLE
                                    end else begin
                                        // Count candidates with more votes
                                        count <= 5'd0;
                                        if (j_idx < n) begin
                                            if (j_idx != i_idx) begin
                                                if (v_j_gt_v_i_plus_R) begin
                                                    count <= count + 5'd1;
                                                end else if (v_j_eq_v_i_plus_R && last_j_lt_m_minus_1) begin
                                                    count <= count + 5'd1;
                                                end
                                            end
                                            j_idx <= j_idx + 4'd1;
                                        end else begin
                                            // Check if count < k
                                            if (count < k) begin
                                                calc_result <= 4'd2; // POSSIBLE
                                            end else begin
                                                calc_result <= 4'd3; // IMPOSSIBLE
                                            end
                                            i_idx <= i_idx + 4'd1;
                                            j_idx <= 4'd0;
                                            k_idx <= 4'd0;
                                            p_idx <= 4'd0;
                                            q_idx <= 4'd0;
                                            s_idx <= 4'd0;
                                            idx <= 4'd0;
                                            costs_0 <= 5'd0;
                                            costs_1 <= 5'd0;
                                            costs_2 <= 5'd0;
                                            costs_3 <= 5'd0;
                                            costs_4 <= 5'd0;
                                            costs_5 <= 5'd0;
                                            costs_6 <= 5'd0;
                                        end
                                    end
                                end
                            end
                        end
                    end else begin
                        // All candidates processed
                        state <= FINISH;
                    end

                    // Cycle counter protection
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
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