module tomb_raider (
    input clk,
    input rst_n,
    input start,
    input [7:0] grid [0:7][0:7],
    input [3:0] gargoyle_mask,
    output reg [3:0] min_rotations,
    output reg done,
    output reg valid
);

parameter MAX_ITER = 64;
parameter GRID_SIZE = 8;

reg [3:0] state;
reg [3:0] gargoyle_count;
reg [2:0] current_gargoyle;
reg [1:0] current_orientation;
reg [7:0] beam_x, beam_y;
reg [1:0] beam_dir;
reg [5:0] iter_count;
reg [3:0] rotation_count;
reg [3:0] best_rotation;
reg [15:0] connection_mask;

reg [2:0] gargoyle_x [0:3];
reg [2:0] gargoyle_y [0:3];
reg [0:3] gargoyle_type;

reg beam_active;
reg [7:0] visited_mask;
reg [2:0] gargoyle_idx;

localparam [3:0] IDLE = 4'd0;
localparam [3:0] SETUP = 4'd1;
localparam [3:0] SIMULATE_BEAM = 4'd2;
localparam [3:0] CHECK_CONNECTIONS = 4'd3;
localparam [3:0] UPDATE_ROTATION = 4'd4;
localparam [3:0] DONE = 4'd5;

localparam [7:0] EMPTY = 8'd0;
localparam [7:0] OBSTACLE = 8'd1;
localparam [7:0] MIRROR_SLASH = 8'd2;
localparam [7:0] MIRROR_BACKSLASH = 8'd3;
localparam [7:0] GARGOYLE_V = 8'd4;
localparam [7:0] GARGOYLE_H = 8'd5;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        valid <= 1'b0;
        min_rotations <= 4'hF;
        gargoyle_count <= 4'd0;
        iter_count <= 6'd0;
        rotation_count <= 4'd0;
        best_rotation <= 4'hF;
        connection_mask <= 16'd0;
        beam_active <= 1'b0;
        visited_mask <= 8'd0;
        gargoyle_idx <= 3'd0;
        current_gargoyle <= 3'd0;
        current_orientation <= 2'd0;
        beam_x <= 8'd0;
        beam_y <= 8'd0;
        beam_dir <= 2'd0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    state <= SETUP;
                    gargoyle_count <= 4'd0;
                    gargoyle_idx <= 3'd0;
                    current_gargoyle <= 3'd0;
                    current_orientation <= 2'd0;
                    rotation_count <= 4'd0;
                    best_rotation <= 4'hF;
                    connection_mask <= 16'd0;
                end
            end

            SETUP: begin
                if (gargoyle_idx < 8'd64) begin
                    if (grid[gargoyle_idx[6:3]][gargoyle_idx[2:0]] == GARGOYLE_V ||
                        grid[gargoyle_idx[6:3]][gargoyle_idx[2:0]] == GARGOYLE_H) begin
                        if (gargoyle_count < 4'd4) begin
                            gargoyle_x[gargoyle_count[1:0]] <= gargoyle_idx[6:3];
                            gargoyle_y[gargoyle_count[1:0]] <= gargoyle_idx[2:0];
                            gargoyle_type[gargoyle_count[1:0]] <= (grid[gargoyle_idx[6:3]][gargoyle_idx[2:0]] == GARGOYLE_H) ? 1'b1 : 1'b0;
                            gargoyle_count <= gargoyle_count + 4'd1;
                        end
                    end
                    gargoyle_idx <= gargoyle_idx + 8'd1;
                end else begin
                    current_gargoyle <= 3'd0;
                    current_orientation <= 2'd0;
                    rotation_count <= 4'd0;
                    connection_mask <= 16'd0;
                    if (gargoyle_count == 4'd0) begin
                        state <= DONE;
                        done <= 1'b1;
                        valid <= 1'b0;
                        min_rotations <= 4'hF;
                    end else begin
                        state <= SIMULATE_BEAM;
                        iter_count <= 6'd0;
                        beam_active <= 1'b0;
                    end
                end
            end

            SIMULATE_BEAM: begin
                if (current_gargoyle < gargoyle_count && current_orientation < 2'd2 && iter_count < MAX_ITER) begin
                    if (!beam_active) begin
                        beam_active <= 1'b1;
                        beam_x <= gargoyle_x[current_gargoyle[1:0]];
                        beam_y <= gargoyle_y[current_gargoyle[1:0]];
                        if ((gargoyle_type[current_gargoyle[1:0]] ^ current_orientation) == 1'b0) begin
                            beam_dir <= (iter_count[0]) ? 2'd2 : 2'd0;
                        end else begin
                            beam_dir <= (iter_count[0]) ? 2'd1 : 2'd3;
                        end
                        visited_mask <= 8'd0;
                    end else begin
                        case (beam_dir)
                            2'd0: beam_y <= beam_y - 8'd1;
                            2'd1: beam_x <= beam_x + 8'd1;
                            2'd2: beam_y <= beam_y + 8'd1;
                            2'd3: beam_x <= beam_x - 8'd1;
                        endcase

                        if (beam_x >= GRID_SIZE || beam_y >= GRID_SIZE) begin
                            beam_dir <= beam_dir + 2'd2;
                            beam_x <= (beam_x >= GRID_SIZE) ? (GRID_SIZE - 8'd1) : beam_x;
                            beam_y <= (beam_y >= GRID_SIZE) ? (GRID_SIZE - 8'd1) : beam_y;
                        end else begin
                            case (grid[beam_y][beam_x])
                                OBSTACLE: begin
                                    beam_active <= 1'b0;
                                    iter_count <= iter_count + 6'd1;
                                end
                                MIRROR_SLASH: begin
                                    case (beam_dir)
                                        2'd0: beam_dir <= 2'd3;
                                        2'd1: beam_dir <= 2'd2;
                                        2'd2: beam_dir <= 2'd1;
                                        2'd3: beam_dir <= 2'd0;
                                    endcase
                                end
                                MIRROR_BACKSLASH: begin
                                    case (beam_dir)
                                        2'd0: beam_dir <= 2'd1;
                                        2'd1: beam_dir <= 2'd0;
                                        2'd2: beam_dir <= 2'd3;
                                        2'd3: beam_dir <= 2'd2;
                                    endcase
                                end
                                GARGOYLE_V, GARGOYLE_H: begin
                                    if (!visited_mask[beam_y * 8 + beam_x]) begin
                                        visited_mask[beam_y * 8 + beam_x] <= 1'b1;
                                        connection_mask[(current_gargoyle * 8) + (current_orientation * 4) + iter_count[0]] <= 1'b1;
                                    end
                                    beam_active <= 1'b0;
                                    iter_count <= iter_count + 6'd1;
                                end
                                default: begin
                                    iter_count <= iter_count + 6'd1;
                                end
                            endcase
                        end
                    end
                end else if (current_gargoyle < gargoyle_count) begin
                    if (iter_count >= MAX_ITER) begin
                        beam_active <= 1'b0;
                        iter_count <= 6'd0;
                        current_orientation <= current_orientation + 2'd1;
                        if (current_orientation == 2'd1) begin
                            current_orientation <= 2'd0;
                            current_gargoyle <= current_gargoyle + 3'd1;
                        end
                    end else if (iter_count[0]) begin
                        beam_active <= 1'b0;
                        iter_count <= 6'd0;
                        current_orientation <= current_orientation + 2'd1;
                        if (current_orientation == 2'd1) begin
                            current_orientation <= 2'd0;
                            current_gargoyle <= current_gargoyle + 3'd1;
                        end
                    end else begin
                        beam_active <= 1'b0;
                        iter_count <= iter_count + 6'd1;
                    end
                end else begin
                    state <= CHECK_CONNECTIONS;
                    current_gargoyle <= 3'd0;
                    current_orientation <= 2'd0;
                end
            end

            CHECK_CONNECTIONS: begin
                if (current_gargoyle < gargoyle_count) begin
                    if (!connection_mask[(current_gargoyle * 8) + (current_orientation * 4) + 0] ||
                        !connection_mask[(current_gargoyle * 8) + (current_orientation * 4) + 1]) begin
                        rotation_count <= rotation_count + 4'd1;
                    end
                    current_orientation <= current_orientation + 2'd1;
                    if (current_orientation == 2'd1) begin
                        current_orientation <= 2'd0;
                        current_gargoyle <= current_gargoyle + 3'd1;
                    end
                end else begin
                    if (rotation_count < best_rotation) begin
                        best_rotation <= rotation_count;
                    end
                    state <= UPDATE_ROTATION;
                    current_gargoyle <= 3'd0;
                end
            end

            UPDATE_ROTATION: begin
                if (current_gargoyle < gargoyle_count) begin
                    current_gargoyle <= current_gargoyle + 3'd1;
                    rotation_count <= current_gargoyle + 3'd1;
                end else begin
                    state <= DONE;
                    if (best_rotation <= 4'hF) begin
                        min_rotations <= best_rotation;
                        valid <= 1'b1;
                    end else begin
                        min_rotations <= 4'hF;
                        valid <= 1'b0;
                    end
                    done <= 1'b1;
                end
            end

            DONE: begin
                state <= DONE;
            end

            default: state <= IDLE;
        endcase
    end
end

endmodule