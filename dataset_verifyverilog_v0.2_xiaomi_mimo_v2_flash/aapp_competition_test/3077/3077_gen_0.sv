module tower_defense_solver (
    input clk, rst_n, start,
    input [7:0] village_x [0:3], village_y [0:3], village_r [0:3],
    input [7:0] minion_x [0:9], minion_y [0:9],
    input [3:0] n_used,
    input [4:0] m_used,
    input [7:0] max_r,
    output reg [4:0] max_killed,
    output reg done
);

    // State Encoding
    localparam IDLE = 3'b000;
    localparam GEN_CANDIDATES = 3'b001;
    localparam EVALUATE_LOOP = 3'b010;
    localparam COUNT_MINIONS = 3'b011;
    localparam UPDATE_MAX = 3'b100;
    localparam DONE = 3'b101;

    reg [2:0] state;
    reg [2:0] next_state;

    // Registers
    reg [4:0] cand_idx; // 0 to 54
    reg [3:0] i_idx;    // For pairs
    reg [3:0] j_idx;    // For pairs
    reg [2:0] v_idx;    // Village index (0-3)
    reg [3:0] m_idx;    // Minion index (0-9)

    reg signed [15:0] curr_cx;
    reg signed [15:0] curr_cy;

    reg [7:0] safe_r;   // Current safe radius for the candidate
    reg [4:0] current_kill_count;

    // Combinational Logic: Candidate Coordinates
    // We compute curr_cx, curr_cy based on cand_idx and pair indices
    // We use these values to update the registers in specific states.
    // To be precise, we need these values available when we enter EVALUATE_LOOP.
    // The values depend on cand_idx, i_idx, j_idx.
    always @(*) begin
        if (cand_idx < 10 && cand_idx < m_used) begin
            curr_cx = {{8{minion_x[cand_idx][7]}}, minion_x[cand_idx]};
            curr_cy = {{8{minion_y[cand_idx][7]}}, minion_y[cand_idx]};
        end else if (cand_idx < 55 && i_idx < m_used && j_idx < m_used) begin
            // Midpoint approximation for pair intersections
            curr_cx = ({{8{minion_x[i_idx][7]}}, minion_x[i_idx]} + {{8{minion_x[j_idx][7]}}, minion_x[j_idx]}) >>> 1;
            curr_cy = ({{8{minion_y[i_idx][7]}}, minion_y[i_idx]} + {{8{minion_y[j_idx][7]}}, minion_y[j_idx]}) >>> 1;
        end else begin
            curr_cx = 0;
            curr_cy = 0;
        end
    end

    // Combinational Logic: Distance & Square Root
    // Used in EVALUATE_LOOP state
    wire signed [15:0] vx = (v_idx < n_used) ? {{8{village_x[v_idx][7]}}, village_x[v_idx]} : 16'sd0;
    wire signed [15:0] vy = (v_idx < n_used) ? {{8{village_y[v_idx][7]}}, village_y[v_idx]} : 16'sd0;
    wire signed [15:0] vr = (v_idx < n_used) ? {8'b0, village_r[v_idx]} : 16'sd0;

    wire signed [15:0] diff_x = curr_cx - vx;
    wire signed [15:0] diff_y = curr_cy - vy;
    wire signed [31:0] dist_sq = (diff_x * diff_x) + (diff_y * diff_y);

    // Iterative Square Root Combinational Logic
    reg [15:0] sqrt_result;
    always @(*) begin
        integer k;
        reg [15:0] r;
        reg [31:0] sum;
        r = 0;
        for (k = 15; k >= 0; k = k - 1) begin
            sum = (r | (1 << k));
            sum = sum * sum;
            if (sum <= dist_sq[31:0]) begin
                r = r | (1 << k);
            end
        end
        sqrt_result = r;
    end

    // Combinational Logic: Minion Hit Check
    // Used in COUNT_MINIONS state
    wire signed [15:0] mx = {{8{minion_x[m_idx][7]}}, minion_x[m_idx]};
    wire signed [15:0] my = {{8{minion_y[m_idx][7]}}, minion_y[m_idx]};
    wire signed [15:0] diff_mx = mx - curr_cx;
    wire signed [15:0] diff_my = my - curr_cy;
    wire signed [31:0] m_dist_sq = (diff_mx * diff_mx) + (diff_my * diff_my);
    wire signed [31:0] r_sq = safe_r * safe_r;
    wire hit = (m_dist_sq <= r_sq);

    // Next State Logic
    always @(*) begin
        case (state)
            IDLE: next_state = start ? GEN_CANDIDATES : IDLE;

            GEN_CANDIDATES: begin
                if (cand_idx >= 55 || m_used == 0 || n_used == 0) next_state = DONE;
                else next_state = EVALUATE_LOOP;
            end

            EVALUATE_LOOP: begin
                // Check if we have processed all villages (v_idx was incremented in previous cycle)
                if (v_idx >= n_used) begin
                    // Loop finished
                    if (safe_r > 0) next_state = COUNT_MINIONS;
                    else next_state = UPDATE_MAX;
                end else if (v_idx < n_used && (sqrt_result < vr || sqrt_result - vr == 0)) begin
                    // Check current village result for early exit (invalid or zero radius)
                    // Note: This checks the village at current v_idx
                    if (sqrt_result < vr || (sqrt_result - vr == 0 && v_idx == n_used - 1))
                        next_state = UPDATE_MAX; // Early break
                    else
                        next_state = EVALUATE_LOOP;
                end else begin
                    next_state = EVALUATE_LOOP;
                end
            end

            COUNT_MINIONS: begin
                if (m_idx >= m_used) next_state = UPDATE_MAX;
                else next_state = COUNT_MINIONS;
            end

            UPDATE_MAX: next_state = GEN_CANDIDATES;

            DONE: next_state = DONE;

            default: next_state = IDLE;
        endcase
    end

    // Sequential Logic and Datapath Updates
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cand_idx <= 0;
            i_idx <= 0;
            j_idx <= 1;
            v_idx <= 0;
            m_idx <= 0;
            max_killed <= 0;
            current_kill_count <= 0;
            safe_r <= 0;
            done <= 0;
        end else begin
            state <= next_state;
            done <= (next_state == DONE);

            case (next_state)
                IDLE: begin
                    // Reset logic if needed, handled by RST
                end

                GEN_CANDIDATES: begin
                    if (state == IDLE && start) begin
                        cand_idx <= 0;
                        i_idx <= 0;
                        j_idx <= 1;
                        v_idx <= 0;
                        safe_r <= 8'hFF; // Initialize safe_r to max
                    end else if (state == UPDATE_MAX || (state == GEN_CANDIDATES && state != next_state)) begin
                        // Increment candidate index and manage pair indices
                        if (cand_idx < 9) begin
                            // Singles
                            if (cand_idx == 9) begin
                                i_idx <= 0;
                                j_idx <= 1;
                            end
                        end else begin
                            // Pairs: Update (i,j) to next pair
                            // Current (i,j) is valid. We move to next.
                            // We assume we just finished processing (i_idx, j_idx)
                            // Next is (i_idx, j_idx+1) or (i_idx+1, i_idx+2)
                            if (j_idx < m_used - 1) begin
                                j_idx <= j_idx + 1;
                            end else begin
                                i_idx <= i_idx + 1;
                                j_idx <= i_idx + 2;
                            end
                        end
                        cand_idx <= cand_idx + 1;
                        v_idx <= 0;
                        safe_r <= 8'hFF; // Reset safe_r for new candidate
                    end
                end

                EVALUATE_LOOP: begin
                    if (v_idx < n_used) begin
                        // Update safe_r with min value based on current village
                        if (sqrt_result < vr) begin
                            safe_r <= 0; // Invalid
                        end else begin
                            if (sqrt_result - vr < safe_r)
                                safe_r <= sqrt_result - vr;
                        end
                        // Increment village index
                        v_idx <= v_idx + 1;
                    end else begin
                        // Should not be here if transition logic is correct, but safety: increment to break
                        v_idx <= v_idx + 1;
                    end
                end

                COUNT_MINIONS: begin
                    if (state != COUNT_MINIONS) begin
                        // Just entered state
                        current_kill_count <= 0;
                        m_idx <= 0;
                        // Clamp safe_r to max_r here
                        if (safe_r > max_r) safe_r <= max_r;
                    end else begin
                        // Loop
                        if (hit) current_kill_count <= current_kill_count + 1;
                        m_idx <= m_idx + 1;
                    end
                end

                UPDATE_MAX: begin
                    if (current_kill_count > max_killed) begin
                        max_killed <= current_kill_count;
                    end
                end
            endcase
        end
    end

endmodule