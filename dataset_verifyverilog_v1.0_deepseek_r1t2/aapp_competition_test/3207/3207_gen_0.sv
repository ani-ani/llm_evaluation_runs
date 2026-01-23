module ChameleonTrack #(
    parameter N = 4,           // Max number of chameleons
    parameter K = 4,           // Number of colors
    parameter L = 16,          // Stick length (meters)
    parameter FIXED_SHIFT = 8, // Fractional bits for Q8.8
    parameter DATA_WIDTH = 16, // Bit width for position / time
    parameter COLOR_WIDTH = 3, // Bits for color (0..K-1)
    parameter DIST_WIDTH = 32, // Bit width for total distance
    parameter TIME_WIDTH = 16, // Bit width for time values
    parameter IDX_WIDTH = 2    // Bits for chameleon index (N=4)
)(
    input  clk,                           // Clock
    input  rst_n,                         // Active‑low reset
    input  start,                         // Start pulse (1 cycle)

    // Input interface for chameleons
    input  [N-1:0]          valid,        // Valid mask
    input  [DATA_WIDTH-1:0] pos  [0:N-1], // Position (Q8.8)
    input  [COLOR_WIDTH-1:0] color[0:N-1],// Color
    input  [N-1:0]          dir,          // Direction: 0=left, 1=right

    // Output: total distance per color
    output reg [DIST_WIDTH-1:0] total_dist[0:K-1],
    output reg done
);

// State declaration
localparam [2:0] IDLE          = 3'd0;
localparam [2:0] INIT          = 3'd1;
localparam [2:0] FIND_NEXT     = 3'd2;
localparam [2:0] UPDATE        = 3'd3;
localparam [2:0] HANDLE_FALLOFF= 3'd4;
localparam [2:0] HANDLE_COLLISION=3'd5;
localparam [2:0] DONE_STATE    = 3'd6;

reg [2:0] current_state, next_state;

// Chameleon state registers
reg                  active   [0:N-1];
reg [DATA_WIDTH-1:0] pos_reg  [0:N-1];
reg [COLOR_WIDTH-1:0] color_reg[0:N-1];
reg                  dir_reg  [0:N-1];
reg [DIST_WIDTH-1:0] personal_dist[0:N-1];

// Event registers
reg [TIME_WIDTH-1:0] dt;
reg [IDX_WIDTH-1:0] event_idx1, event_idx2;
reg                 event_is_collision;

// Helper functions
function [TIME_WIDTH-1:0] get_fall_time;
    input active_in;
    input dir_in;
    input [DATA_WIDTH-1:0] pos_in;
begin
    if (!active_in) begin
        get_fall_time = {TIME_WIDTH{1'b1}};
    end
    else if (dir_in) begin
        get_fall_time = (L * (1 << FIXED_SHIFT)) - pos_in;
    end
    else begin
        get_fall_time = pos_in;
    end
end
endfunction

function [TIME_WIDTH-1:0] get_collision_time;
    input active_i;
    input active_j;
    input dir_i;
    input dir_j;
    input [DATA_WIDTH-1:0] pos_i;
    input [DATA_WIDTH-1:0] pos_j;
    reg [TIME_WIDTH-1:0] temp_time;
begin
    temp_time = {TIME_WIDTH{1'b1}};
    if (active_i && active_j) begin
        if (dir_i && !dir_j && pos_i < pos_j) begin
            temp_time = (pos_j - pos_i) >> 1;
        end
        else if (!dir_i && dir_j && pos_i > pos_j) begin
            temp_time = (pos_i - pos_j) >> 1;
        end
    end
    get_collision_time = temp_time;
end
endfunction

// Combinational event finding
reg [TIME_WIDTH-1:0] min_time;
reg [IDX_WIDTH-1:0] min_idx1, min_idx2;
reg                 min_is_collision;
reg                 found_event;

integer i, j;
always @(*) begin
    min_time = {TIME_WIDTH{1'b1}};
    min_idx1 = 0;
    min_idx2 = 0;
    min_is_collision = 0;
    found_event = 0;

    // Fall-off events
    for (i = 0; i < N; i = i + 1) begin
        if (active[i]) begin
            [TIME_WIDTH-1:0] fall_time = get_fall_time(active[i], dir_reg[i], pos_reg[i]);
            if (fall_time < min_time) begin
                min_time = fall_time;
                min_idx1 = i[IDX_WIDTH-1:0];
                min_is_collision = 0;
                found_event = 1;
            end
        end
    end

    // Collision events
    for (i = 0; i < N; i = i + 1) begin
        for (j = i+1; j < N; j = j + 1) begin
            if (active[i] && active[j]) begin
                [TIME_WIDTH-1:0] coll_time = get_collision_time(
                    active[i], active[j], dir_reg[i], dir_reg[j], pos_reg[i], pos_reg[j]);
                if (coll_time < min_time) begin
                    min_time = coll_time;
                    min_idx1 = i[IDX_WIDTH-1:0];
                    min_idx2 = j[IDX_WIDTH-1:0];
                    min_is_collision = 1;
                    found_event = 1;
                end
            end
        end
    end
end

// Collision color update
wire [COLOR_WIDTH-1:0] new_color_i, new_color_j;
assign new_color_i = color_reg[event_idx2];
assign new_color_j = (color_reg[event_idx1] + color_reg[event_idx2]) % K;

// FSM and datapath
always @(posedge clk or negedge rst_n) begin
    integer k;
    if (!rst_n) begin
        current_state <= IDLE;
        for (k = 0; k < N; k = k + 1) begin
            active[k] <= 1'b0;
            pos_reg[k] <= {DATA_WIDTH{1'b0}};
            color_reg[k] <= {COLOR_WIDTH{1'b0}};
            dir_reg[k] <= 1'b0;
            personal_dist[k] <= {DIST_WIDTH{1'b0}};
        end
        for (k = 0; k < K; k = k + 1) begin
            total_dist[k] <= {DIST_WIDTH{1'b0}};
        end
        done <= 1'b0;
        dt <= {TIME_WIDTH{1'b0}};
        event_idx1 <= {IDX_WIDTH{1'b0}};
        event_idx2 <= {IDX_WIDTH{1'b0}};
        event_is_collision <= 1'b0;
    end
    else begin
        case (current_state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    current_state <= INIT;
                end
            end

            INIT: begin
                for (k = 0; k < N; k = k + 1) begin
                    active[k] <= valid[k];
                    pos_reg[k] <= pos[k];
                    color_reg[k] <= color[k];
                    dir_reg[k] <= dir[k];
                    personal_dist[k] <= {DIST_WIDTH{1'b0}};
                end
                current_state <= FIND_NEXT;
            end

            FIND_NEXT: begin
                if (found_event && min_time != {TIME_WIDTH{1'b1}}) begin
                    dt <= min_time;
                    event_idx1 <= min_idx1;
                    event_idx2 <= min_idx2;
                    event_is_collision <= min_is_collision;
                    current_state <= UPDATE;
                end
                else begin
                    current_state <= DONE_STATE;
                end
            end

            UPDATE: begin
                for (k = 0; k < N; k = k + 1) begin
                    if (active[k]) begin
                        if (dir_reg[k]) begin
                            pos_reg[k] <= pos_reg[k] + dt;
                        end
                        else begin
                            pos_reg[k] <= pos_reg[k] - dt;
                        end
                        personal_dist[k] <= personal_dist[k] + dt;
                    end
                end
                if (event_is_collision) begin
                    current_state <= HANDLE_COLLISION;
                end
                else begin
                    current_state <= HANDLE_FALLOFF;
                end
            end

            HANDLE_FALLOFF: begin
                if (active[event_idx1]) begin
                    total_dist[color_reg[event_idx1]] <= total_dist[color_reg[event_idx1]] + personal_dist[event_idx1];
                    active[event_idx1] <= 1'b0;
                end
                current_state <= FIND_NEXT;
            end

            HANDLE_COLLISION: begin
                if (active[event_idx1] && active[event_idx2]) begin
                    color_reg[event_idx1] <= new_color_i;
                    color_reg[event_idx2] <= new_color_j;
                    dir_reg[event_idx1] <= ~dir_reg[event_idx1];
                    dir_reg[event_idx2] <= ~dir_reg[event_idx2];
                end
                current_state <= FIND_NEXT;
            end

            DONE_STATE: begin
                done <= 1'b1;
                if (!start) begin
                    current_state <= IDLE;
                end
            end

            default: current_state <= IDLE;
        endcase
    end
end

endmodule