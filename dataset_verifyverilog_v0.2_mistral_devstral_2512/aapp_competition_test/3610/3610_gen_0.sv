module vertex_cover_solver (
    input clk,
    input rst_n,
    input start,
    input [9:0] team_stockholm,
    input [9:0] team_london,
    input team_valid,
    input team_done,
    output reg [4:0] result_count,
    output reg [9:0] result_ids [0:15],
    output reg result_valid,
    output reg done
);

    // States
    typedef enum logic [1:0] {
        IDLE,
        INPUT_TEAMS,
        COMPUTE_COVER,
        OUTPUT_RESULT
    } state_t;

    state_t state, next_state;

    // Internal registers
    reg [3:0] stockholm_count = 0;
    reg [3:0] london_count = 0;
    reg [3:0] stockholm_idx = 0;
    reg [3:0] london_idx = 0;
    reg [9:0] stockholm_ids [0:15];
    reg [9:0] london_ids [0:15];
    reg [15:0] stockholm_mask = 0;
    reg [15:0] london_mask = 0;
    reg [15:0] stockholm_degree [0:15];
    reg [15:0] london_degree [0:15];
    reg [15:0] edge_matrix [0:15];
    reg [3:0] cover_count = 0;
    reg [9:0] cover_ids [0:15];
    reg friend_in_cover = 0;
    reg friend_candidate = 0;

    // Friend ID
    localparam FRIEND_ID = 1009;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_valid <= 0;
            done <= 0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = INPUT_TEAMS;
            end
            INPUT_TEAMS: begin
                if (team_done) next_state = COMPUTE_COVER;
            end
            COMPUTE_COVER: begin
                if (done) next_state = OUTPUT_RESULT;
            end
            OUTPUT_RESULT: begin
                if (done) next_state = IDLE;
            end
        endcase
    end

    // Input teams
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stockholm_count <= 0;
            london_count <= 0;
            stockholm_idx <= 0;
            london_idx <= 0;
            for (int i = 0; i < 16; i++) begin
                stockholm_ids[i] <= 0;
                london_ids[i] <= 0;
            end
        end else if (state == INPUT_TEAMS && team_valid) begin
            // Check if Stockholm ID is new
            reg found_s = 0;
            for (int i = 0; i < stockholm_count; i++) begin
                if (stockholm_ids[i] == team_stockholm) found_s = 1;
            end
            if (!found_s && team_stockholm >= 1000 && team_stockholm <= 1999 && stockholm_count < 16) begin
                stockholm_ids[stockholm_count] <= team_stockholm;
                stockholm_count <= stockholm_count + 1;
            end

            // Check if London ID is new
            reg found_l = 0;
            for (int i = 0; i < london_count; i++) begin
                if (london_ids[i] == team_london) found_l = 1;
            end
            if (!found_l && team_london >= 2000 && team_london <= 2999 && london_count < 16) begin
                london_ids[london_count] <= team_london;
                london_count <= london_count + 1;
            end

            // Add edge if both IDs are valid
            if (!found_s && !found_l && team_stockholm >= 1000 && team_stockholm <= 1999 && team_london >= 2000 && team_london <= 2999) begin
                edge_matrix[stockholm_idx][london_idx] <= 1;
                stockholm_degree[stockholm_idx] <= stockholm_degree[stockholm_idx] + 1;
                london_degree[london_idx] <= london_degree[london_idx] + 1;
                stockholm_idx <= stockholm_idx + 1;
                london_idx <= london_idx + 1;
            end
        end
    end

    // Compute cover
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 16; i++) begin
                stockholm_degree[i] <= 0;
                london_degree[i] <= 0;
                for (int j = 0; j < 16; j++) begin
                    edge_matrix[i][j] <= 0;
                end
            end
            stockholm_mask <= 0;
            london_mask <= 0;
            cover_count <= 0;
            friend_in_cover <= 0;
            friend_candidate <= 0;
        end else if (state == COMPUTE_COVER) begin
            // Greedy algorithm
            reg [3:0] max_degree = 0;
            reg [3:0] max_idx = 0;
            reg [3:0] max_side = 0; // 0: Stockholm, 1: London
            reg [3:0] friend_idx = 0;
            reg friend_found = 0;

            // Check if friend is in any edge
            for (int i = 0; i < stockholm_count; i++) begin
                if (stockholm_ids[i] == FRIEND_ID) begin
                    friend_idx = i;
                    friend_found = 1;
                end
            end

            // Find vertex with highest degree
            for (int i = 0; i < stockholm_count; i++) begin
                if (stockholm_degree[i] > max_degree && !stockholm_mask[i]) begin
                    max_degree = stockholm_degree[i];
                    max_idx = i;
                    max_side = 0;
                end
            end
            for (int i = 0; i < london_count; i++) begin
                if (london_degree[i] > max_degree && !london_mask[i]) begin
                    max_degree = london_degree[i];
                    max_idx = i;
                    max_side = 1;
                end
            end

            // Prefer friend if degree is equal
            if (friend_found && stockholm_degree[friend_idx] == max_degree && max_side == 0 && !stockholm_mask[friend_idx]) begin
                max_idx = friend_idx;
                friend_candidate = 1;
            end

            // Add to cover
            if (max_degree > 0) begin
                if (max_side == 0) begin
                    stockholm_mask[max_idx] = 1;
                    cover_ids[cover_count] = stockholm_ids[max_idx];
                    if (stockholm_ids[max_idx] == FRIEND_ID) friend_in_cover = 1;
                end else begin
                    london_mask[max_idx] = 1;
                    cover_ids[cover_count] = london_ids[max_idx];
                end
                cover_count <= cover_count + 1;

                // Remove covered edges
                if (max_side == 0) begin
                    for (int j = 0; j < london_count; j++) begin
                        if (edge_matrix[max_idx][j]) begin
                            edge_matrix[max_idx][j] = 0;
                            london_degree[j] = london_degree[j] - 1;
                        end
                    end
                end else begin
                    for (int j = 0; j < stockholm_count; j++) begin
                        if (edge_matrix[j][max_idx]) begin
                            edge_matrix[j][max_idx] = 0;
                            stockholm_degree[j] = stockholm_degree[j] - 1;
                        end
                    end
                end
            end else begin
                // Check if friend can be added without increasing cover size
                if (friend_found && !friend_in_cover && !stockholm_mask[friend_idx]) begin
                    reg can_add = 1;
                    for (int j = 0; j < london_count; j++) begin
                        if (edge_matrix[friend_idx][j] && !london_mask[j]) begin
                            can_add = 0;
                        end
                    end
                    if (can_add) begin
                        stockholm_mask[friend_idx] = 1;
                        cover_ids[cover_count] = stockholm_ids[friend_idx];
                        cover_count <= cover_count + 1;
                        friend_in_cover = 1;
                    end
                end
                done <= 1;
            end
        end
    end

    // Output result
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result_count <= 0;
            for (int i = 0; i < 16; i++) begin
                result_ids[i] <= 0;
            end
            result_valid <= 0;
        end else if (state == OUTPUT_RESULT) begin
            // Sort cover IDs
            reg [9:0] temp_ids [0:15];
            for (int i = 0; i < cover_count; i++) begin
                temp_ids[i] = cover_ids[i];
            end

            // Bubble sort
            for (int i = 0; i < cover_count - 1; i++) begin
                for (int j = 0; j < cover_count - i - 1; j++) begin
                    if (temp_ids[j] > temp_ids[j + 1]) begin
                        reg [9:0] temp = temp_ids[j];
                        temp_ids[j] = temp_ids[j + 1];
                        temp_ids[j + 1] = temp;
                    end
                end
            end

            // Output sorted IDs
            for (int i = 0; i < 16; i++) begin
                if (i < cover_count) begin
                    result_ids[i] <= temp_ids[i];
                end else begin
                    result_ids[i] <= 0;
                end
            end
            result_count <= cover_count;
            result_valid <= 1;
            done <= 1;
        end
    end

endmodule