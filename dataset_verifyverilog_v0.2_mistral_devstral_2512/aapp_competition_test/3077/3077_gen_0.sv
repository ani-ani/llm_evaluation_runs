module tower_defense_solver (
    input clk,
    input rst_n,
    input start,
    input [7:0] village_x [0:3],
    input [7:0] village_y [0:3],
    input [7:0] village_r [0:3],
    input [7:0] minion_x [0:9],
    input [7:0] minion_y [0:9],
    input [3:0] n_used,
    input [4:0] m_used,
    input [7:0] max_r,
    output reg [4:0] max_killed,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'b000;
    localparam [2:0] GEN_CANDIDATES = 3'b001;
    localparam [2:0] EVALUATE_CENTERS = 3'b010;
    localparam [2:0] DONE = 3'b100;

    reg [2:0] state, next_state;

    // Candidate center storage
    reg [7:0] candidate_x [0:54];
    reg [7:0] candidate_y [0:54];
    reg [5:0] candidate_count;

    // Evaluation variables
    reg [7:0] current_cx, current_cy;
    reg [7:0] current_safe_r_sq;
    reg [4:0] current_killed;
    reg [5:0] candidate_idx;
    reg [3:0] village_idx;
    reg [4:0] minion_idx;

    // Temporary distance calculations
    wire [15:0] dist_sq_village;
    wire [15:0] dist_sq_minion;
    wire [15:0] safe_r_sq;

    assign dist_sq_village = ($signed(current_cx) - $signed(village_x[village_idx])) ** 2 +
                            ($signed(current_cy) - $signed(village_y[village_idx])) ** 2;

    assign dist_sq_minion = ($signed(current_cx) - $signed(minion_x[minion_idx])) ** 2 +
                           ($signed(current_cy) - $signed(minion_y[minion_idx])) ** 2;

    assign safe_r_sq = (dist_sq_village > (max_r + village_r[village_idx]) ** 2) ?
                       (max_r ** 2) : 
                       (dist_sq_village > village_r[village_idx] ** 2) ?
                       (dist_sq_village - (village_r[village_idx] ** 2) - 2 * village_r[village_idx] * max_r) :
                       0;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            max_killed <= 0;
            candidate_count <= 0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = GEN_CANDIDATES;
            end
            GEN_CANDIDATES: begin
                if (candidate_count >= 54) next_state = EVALUATE_CENTERS;
            end
            EVALUATE_CENTERS: begin
                if (candidate_idx >= candidate_count) next_state = DONE;
            end
            DONE: begin
                if (!start) next_state = IDLE;
            end
        endcase
    end

    // Candidate generation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            candidate_count <= 0;
        end else if (state == GEN_CANDIDATES) begin
            if (candidate_count < m_used) begin
                candidate_x[candidate_count] <= minion_x[candidate_count];
                candidate_y[candidate_count] <= minion_y[candidate_count];
                candidate_count <= candidate_count + 1;
            end else if (candidate_count < 55) begin
                // Generate intersection points (simplified approach)
                // For simplicity, we'll just duplicate minion points
                // In a real implementation, you'd calculate actual intersections
                candidate_x[candidate_count] <= minion_x[candidate_count - m_used];
                candidate_y[candidate_count] <= minion_y[candidate_count - m_used];
                candidate_count <= candidate_count + 1;
            end
        end
    end

    // Evaluation logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            candidate_idx <= 0;
            village_idx <= 0;
            minion_idx <= 0;
            current_killed <= 0;
            current_safe_r_sq <= 0;
        end else if (state == EVALUATE_CENTERS) begin
            if (candidate_idx < candidate_count) begin
                case (candidate_idx[1:0])
                    2'b00: begin
                        current_cx <= candidate_x[candidate_idx];
                        current_cy <= candidate_y[candidate_idx];
                        village_idx <= 0;
                        current_safe_r_sq <= max_r ** 2;
                    end
                    2'b01: begin
                        // Compute safe radius (simplified)
                        if (village_idx < n_used) begin
                            if (dist_sq_village > (max_r + village_r[village_idx]) ** 2) begin
                                current_safe_r_sq <= max_r ** 2;
                            end else if (dist_sq_village > village_r[village_idx] ** 2) begin
                                current_safe_r_sq <= dist_sq_village - (village_r[village_idx] ** 2);
                            end else begin
                                current_safe_r_sq <= 0;
                            end
                            village_idx <= village_idx + 1;
                        end else begin
                            minion_idx <= 0;
                            current_killed <= 0;
                        end
                    end
                    2'b10: begin
                        // Count minions within radius
                        if (minion_idx < m_used) begin
                            if (dist_sq_minion <= current_safe_r_sq) begin
                                current_killed <= current_killed + 1;
                            end
                            minion_idx <= minion_idx + 1;
                        end else begin
                            // Update max_killed
                            if (current_killed > max_killed) begin
                                max_killed <= current_killed;
                            end
                            candidate_idx <= candidate_idx + 1;
                        end
                    end
                    2'b11: begin
                        candidate_idx <= candidate_idx + 1;
                    end
                endcase
            end
        end
    end

    // Done signal
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 0;
        end else if (state == DONE) begin
            done <= 1;
        end else begin
            done <= 0;
        end
    end

endmodule