module lava_game(
    input clk,
    input rst_n,
    input start,
    input [15:0] A,
    input [15:0] F,
    input [7:0] map_data,
    input [2:0] map_index,
    output reg [1:0] result,
    output reg done
);

    // Parameters
    localparam IDLE = 3'b000;
    localparam LOAD = 3'b001;
    localparam ELSA_PROCESS = 3'b010;
    localparam FATHER_PROCESS = 3'b011;
    localparam COMPARE = 3'b100;
    localparam DONE = 3'b101;

    localparam RES_NO_WAY = 2'b00;
    localparam RES_NO_CHANCE = 2'b01;
    localparam RES_GO_FOR_IT = 2'b10;
    localparam RES_SUCCESS = 2'b11;

    localparam TILE_W = 2'b00;
    localparam TILE_B = 2'b01;
    localparam TILE_S = 2'b10;
    localparam TILE_G = 2'b11;

    // State
    reg [2:0] state;
    reg [1:0] map [0:63];
    reg [6:0] load_cnt;
    reg load_complete;

    // Elsa BFS Registers
    reg [5:0] elsa_visited [0:63];
    reg [5:0] elsa_frontier [0:63];
    reg [5:0] elsa_next_frontier [0:63];
    reg [5:0] elsa_step_count;
    reg [5:0] elsa_start_idx;
    reg [5:0] elsa_end_idx;
    reg [5:0] elsa_next_idx;
    reg [5:0] elsa_search_idx;
    reg elsa_reached;
    reg elsa_done_processing;
    reg [5:0] elsa_current_steps;

    // Father BFS Registers
    reg [5:0] father_visited [0:63];
    reg [5:0] father_frontier [0:63];
    reg [5:0] father_next_frontier [0:63];
    reg [5:0] father_step_count;
    reg [5:0] father_start_idx;
    reg [5:0] father_end_idx;
    reg [5:0] father_next_idx;
    reg [5:0] father_search_idx;
    reg father_reached;
    reg father_done_processing;
    reg [5:0] father_current_steps;

    // Temporaries
    reg [5:0] curr_tile;
    reg [2:0] neighbor_row, neighbor_col;
    reg [5:0] neighbor_idx;
    integer i;

    // FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            case (state)
                IDLE: if (start) state <= LOAD;
                LOAD: if (load_complete) state <= ELSA_PROCESS;
                ELSA_PROCESS: if (elsa_done_processing) state <= FATHER_PROCESS;
                FATHER_PROCESS: if (father_done_processing) state <= COMPARE;
                COMPARE: state <= DONE;
                DONE: state <= DONE;
            endcase
        end
    end

    // LOAD Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            load_cnt <= 0;
            load_complete <= 0;
        end else if (state == IDLE && start) begin
            load_cnt <= 0;
            load_complete <= 0;
        end else if (state == LOAD) begin
            if (map_index < 64 && load_cnt < 64) begin
                map[map_index] <= map_data[1:0];
                load_cnt <= load_cnt + 1;
            end
            if (load_cnt == 63) load_complete <= 1;
        end
    end

    // ELSA_PROCESS Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 64; i = i + 1) begin
                elsa_visited[i] <= 0;
                elsa_frontier[i] <= 0;
                elsa_next_frontier[i] <= 0;
            end
            elsa_step_count <= 0;
            elsa_start_idx <= 0;
            elsa_end_idx <= 0;
            elsa_next_idx <= 0;
            elsa_search_idx <= 0;
            elsa_reached <= 0;
            elsa_done_processing <= 0;
            elsa_current_steps <= 0;
        end else if (state == ELSA_PROCESS) begin
            if (!elsa_reached) begin
                if (elsa_start_idx == elsa_end_idx) begin
                    if (elsa_next_idx == 0) elsa_done_processing <= 1;
                    else begin
                        elsa_frontier <= elsa_next_frontier;
                        elsa_end_idx <= elsa_next_idx;
                        elsa_start_idx <= 0;
                        elsa_next_idx <= 0;
                        elsa_step_count <= elsa_step_count + 1;
                        if (elsa_step_count >= 62) elsa_done_processing <= 1;
                    end
                end else begin
                    curr_tile <= elsa_frontier[elsa_start_idx];
                    if (map[elsa_frontier[elsa_start_idx]] == TILE_G) begin
                        elsa_current_steps <= elsa_step_count;
                        elsa_done_processing <= 1;
                        elsa_reached <= 1;
                    end else begin
                        elsa_reached <= 1;
                        elsa_search_idx <= 0;
                    end
                end
            end else begin // Reached processing
                if (elsa_search_idx < 8) begin
                    // Calculate neighbor
                    case (elsa_search_idx)
                        0: begin neighbor_row = (curr_tile[5:3] > 0) ? curr_tile[5:3] - 1 : 0; neighbor_col = curr_tile[2:0]; end
                        1: begin neighbor_row = (curr_tile[5:3] < 7) ? curr_tile[5:3] + 1 : 0; neighbor_col = curr_tile[2:0]; end
                        2: begin neighbor_row = curr_tile[5:3]; neighbor_col = (curr_tile[2:0] < 7) ? curr_tile[2:0] + 1 : 0; end
                        3: begin neighbor_row = curr_tile[5:3]; neighbor_col = (curr_tile[2:0] > 0) ? curr_tile[2:0] - 1 : 0; end
                        4: begin neighbor_row = (curr_tile[5:3] > 0) ? curr_tile[5:3] - 1 : 0; neighbor_col = (curr_tile[2:0] < 7) ? curr_tile[2:0] + 1 : 0; end
                        5: begin neighbor_row = (curr_tile[5:3] > 0) ? curr_tile[5:3] - 1 : 0; neighbor_col = (curr_tile[2:0] > 0) ? curr_tile[2:0] - 1 : 0; end
                        6: begin neighbor_row = (curr_tile[5:3] < 7) ? curr_tile[5:3] + 1 : 0; neighbor_col = (curr_tile[2:0] < 7) ? curr_tile[2:0] + 1 : 0; end
                        7: begin neighbor_row = (curr_tile[5:3] < 7) ? curr_tile[5:3] + 1 : 0; neighbor_col = (curr_tile[2:0] > 0) ? curr_tile[2:0] - 1 : 0; end
                    endcase
                    neighbor_idx = {neighbor_row, neighbor_col};
                    if (!elsa_visited[neighbor_idx] && (map[neighbor_idx] != TILE_B)) begin
                        reg [2:0] dx, dy;
                        dx = (curr_tile[2:0] > neighbor_col) ? curr_tile[2:0] - neighbor_col : neighbor_col - curr_tile[2:0];
                        dy = (curr_tile[5:3] > neighbor_row) ? curr_tile[5:3] - neighbor_row : neighbor_row - curr_tile[5:3];
                        if ((dx + dy == 1 && A >= 65536) || (dx + dy == 2 && A >= 92682)) begin
                            elsa_next_frontier[elsa_next_idx] <= neighbor_idx;
                            elsa_visited[neighbor_idx] <= 1;
                            elsa_next_idx <= elsa_next_idx + 1;
                        end
                    end
                    elsa_search_idx <= elsa_search_idx + 1;
                end else begin
                    // Done with neighbors
                    elsa_start_idx <= elsa_start_idx + 1;
                    elsa_reached <= 0;
                end
            end
        end
    end

    // FATHER_PROCESS Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 64; i = i + 1) begin
                father_visited[i] <= 0;
                father_frontier[i] <= 0;
                father_next_frontier[i] <= 0;
            end
            father_step_count <= 0;
            father_start_idx <= 0;
            father_end_idx <= 0;
            father_next_idx <= 0;
            father_search_idx <= 0;
            father_reached <= 0;
            father_done_processing <= 0;
            father_current_steps <= 0;
        end else if (state == FATHER_PROCESS) begin
            if (!father_reached) begin
                if (father_start_idx == father_end_idx) begin
                    if (father_next_idx == 0) father_done_processing <= 1;
                    else begin
                        father_frontier <= father_next_frontier;
                        father_end_idx <= father_next_idx;
                        father_start_idx <= 0;
                        father_next_idx <= 0;
                        father_step_count <= father_step_count + 1;
                        if (father_step_count >= 62) father_done_processing <= 1;
                    end
                end else begin
                    curr_tile <= father_frontier[father_start_idx];
                    if (map[father_frontier[father_start_idx]] == TILE_G) begin
                        father_current_steps <= father_step_count;
                        father_done_processing <= 1;
                        father_reached <= 1;
                    end else begin
                        father_reached <= 1;
                        father_search_idx <= 0;
                    end
                end
            end else begin // Reached processing
                if (father_search_idx < 4) begin // Only 4 directions for Father
                    // Calculate neighbor for `father_search_idx`
                    case (father_search_idx)
                        0: begin neighbor_row = (curr_tile[5:3] > 0) ? curr_tile[5:3] - 1 : 0; neighbor_col = curr_tile[2:0]; end
                        1: begin neighbor_row = (curr_tile[5:3] < 7) ? curr_tile[5:3] + 1 : 0; neighbor_col = curr_tile[2:0]; end
                        2: begin neighbor_row = curr_tile[5:3]; neighbor_col = (curr_tile[2:0] < 7) ? curr_tile[2:0] + 1 : 0; end
                        3: begin neighbor_row = curr_tile[5:3]; neighbor_col = (curr_tile[2:0] > 0) ? curr_tile[2:0] - 1 : 0; end
                    endcase
                    neighbor_idx = {neighbor_row, neighbor_col};
                    if (!father_visited[neighbor_idx] && (map[neighbor_idx] != TILE_B)) begin
                        // Manhattan check: |dx| + |dy| <= F
                        // Since neighbors are adjacent, |dx| + |dy| = 1.
                        // Check if F >= 1.0 (65536)
                        if (F >= 65536) begin
                            father_next_frontier[father_next_idx] <= neighbor_idx;
                            father_visited[neighbor_idx] <= 1;
                            father_next_idx <= father_next_idx + 1;
                        end
                    end
                    father_search_idx <= father_search_idx + 1;
                end else begin
                    // Done with neighbors
                    father_start_idx <= father_start_idx + 1;
                    father_reached <= 0;
                end
            end
        end
    end

    // COMPARE Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= RES_NO_WAY;
            done <= 0;
        end else if (state == COMPARE) begin
            if (elsa_reached && father_reached) begin
                if (elsa_current_steps < father_current_steps) result <= RES_GO_FOR_IT;
                else if (elsa_current_steps > father_current_steps) result <= RES_NO_CHANCE;
                else result <= RES_SUCCESS;
            end else if (elsa_reached && !father_reached) begin
                result <= RES_GO_FOR_IT;
            end else if (!elsa_reached && father_reached) begin
                result <= RES_NO_CHANCE;
            end else begin
                result <= RES_NO_WAY;
            end
            done <= 1;
        end else if (state == DONE) begin
            done <= 1;
        end else if (state == IDLE) begin
            done <= 0;
            result <= 0;
        end
    end

endmodule