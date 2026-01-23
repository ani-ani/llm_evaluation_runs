module cube_constructor (
    input clk,
    input rst_n,
    input start,
    input [7:0] tile0_tl, tile0_tr, tile0_br, tile0_bl,
    input [7:0] tile1_tl, tile1_tr, tile1_br, tile1_bl,
    input [7:0] tile2_tl, tile2_tr, tile2_br, tile2_bl,
    input [7:0] tile3_tl, tile3_tr, tile3_br, tile3_bl,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    typedef enum logic [1:0] {
        IDLE,
        PROCESSING,
        DONE
    } state_t;

    state_t state;
    reg [31:0] count;
    reg [31:0] cycle_count;

    // Tile rotation function
    function [7:0] rotate_tile;
        input [7:0] tl, tr, br, bl;
        input [1:0] rotation;
        case (rotation)
            2'b00: rotate_tile = tl;
            2'b01: rotate_tile = tr;
            2'b10: rotate_tile = br;
            2'b11: rotate_tile = bl;
        endcase
    endfunction

    // Tile structure
    typedef struct {
        logic [7:0] tl;
        logic [7:0] tr;
        logic [7:0] br;
        logic [7:0] bl;
    } tile_t;

    tile_t tiles [0:3];
    reg [1:0] tile0_rot;
    reg [1:0] tile1_rot;
    reg [1:0] tile2_rot;
    reg [1:0] tile3_rot;
    reg [1:0] tile1_idx;
    reg [1:0] tile2_idx;
    reg [1:0] tile3_idx;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 0;
            done <= 0;
            count <= 0;
            cycle_count <= 0;
            tile0_rot <= 0;
            tile1_rot <= 0;
            tile2_rot <= 0;
            tile3_rot <= 0;
            tile1_idx <= 0;
            tile2_idx <= 0;
            tile3_idx <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= PROCESSING;
                        count <= 0;
                        cycle_count <= 0;
                        tile0_rot <= 0;
                        tile1_rot <= 0;
                        tile2_rot <= 0;
                        tile3_rot <= 0;
                        tile1_idx <= 0;
                        tile2_idx <= 0;
                        tile3_idx <= 0;
                        done <= 0;
                    end
                end
                PROCESSING: begin
                    if (cycle_count == 31) begin
                        state <= DONE;
                        result <= count;
                        done <= 1;
                    end else begin
                        // Initialize tiles
                        tiles[0].tl = tile0_tl;
                        tiles[0].tr = tile0_tr;
                        tiles[0].br = tile0_br;
                        tiles[0].bl = tile0_bl;
                        tiles[1].tl = tile1_tl;
                        tiles[1].tr = tile1_tr;
                        tiles[1].br = tile1_br;
                        tiles[1].bl = tile1_bl;
                        tiles[2].tl = tile2_tl;
                        tiles[2].tr = tile2_tr;
                        tiles[2].br = tile2_br;
                        tiles[2].bl = tile2_bl;
                        tiles[3].tl = tile3_tl;
                        tiles[3].tr = tile3_tr;
                        tiles[3].br = tile3_br;
                        tiles[3].bl = tile3_bl;

                        // Check if current configuration is valid
                        logic valid;
                        logic [7:0] tile0_tl_rot = rotate_tile(tiles[0].tl, tiles[0].tr, tiles[0].br, tiles[0].bl, tile0_rot);
                        logic [7:0] tile0_tr_rot = rotate_tile(tiles[0].tr, tiles[0].br, tiles[0].bl, tiles[0].tl, tile0_rot);
                        logic [7:0] tile0_br_rot = rotate_tile(tiles[0].br, tiles[0].bl, tiles[0].tl, tiles[0].tr, tile0_rot);
                        logic [7:0] tile0_bl_rot = rotate_tile(tiles[0].bl, tiles[0].tl, tiles[0].tr, tiles[0].br, tile0_rot);

                        logic [7:0] tile1_tl_rot = rotate_tile(tiles[tile1_idx].tl, tiles[tile1_idx].tr, tiles[tile1_idx].br, tiles[tile1_idx].bl, tile1_rot);
                        logic [7:0] tile1_tr_rot = rotate_tile(tiles[tile1_idx].tr, tiles[tile1_idx].br, tiles[tile1_idx].bl, tiles[tile1_idx].tl, tile1_rot);
                        logic [7:0] tile1_br_rot = rotate_tile(tiles[tile1_idx].br, tiles[tile1_idx].bl, tiles[tile1_idx].tl, tiles[tile1_idx].tr, tile1_rot);
                        logic [7:0] tile1_bl_rot = rotate_tile(tiles[tile1_idx].bl, tiles[tile1_idx].tl, tiles[tile1_idx].tr, tiles[tile1_idx].br, tile1_rot);

                        logic [7:0] tile2_tl_rot = rotate_tile(tiles[tile2_idx].tl, tiles[tile2_idx].tr, tiles[tile2_idx].br, tiles[tile2_idx].bl, tile2_rot);
                        logic [7:0] tile2_tr_rot = rotate_tile(tiles[tile2_idx].tr, tiles[tile2_idx].br, tiles[tile2_idx].bl, tiles[tile2_idx].tl, tile2_rot);
                        logic [7:0] tile2_br_rot = rotate_tile(tiles[tile2_idx].br, tiles[tile2_idx].bl, tiles[tile2_idx].tl, tiles[tile2_idx].tr, tile2_rot);
                        logic [7:0] tile2_bl_rot = rotate_tile(tiles[tile2_idx].bl, tiles[tile2_idx].tl, tiles[tile2_idx].tr, tiles[tile2_idx].br, tile2_rot);

                        logic [7:0] tile3_tl_rot = rotate_tile(tiles[tile3_idx].tl, tiles[tile3_idx].tr, tiles[tile3_idx].br, tiles[tile3_idx].bl, tile3_rot);
                        logic [7:0] tile3_tr_rot = rotate_tile(tiles[tile3_idx].tr, tiles[tile3_idx].br, tiles[tile3_idx].bl, tiles[tile3_idx].tl, tile3_rot);
                        logic [7:0] tile3_br_rot = rotate_tile(tiles[tile3_idx].br, tiles[tile3_idx].bl, tiles[tile3_idx].tl, tiles[tile3_idx].tr, tile3_rot);
                        logic [7:0] tile3_bl_rot = rotate_tile(tiles[tile3_idx].bl, tiles[tile3_idx].tl, tiles[tile3_idx].tr, tiles[tile3_idx].br, tile3_rot);

                        // Check all vertices
                        valid = 1;
                        // Top-left vertex
                        if (tile0_tl_rot != tile0_tl_rot) valid = 0;
                        // Top-right vertex
                        if (tile0_tr_rot != tile1_tl_rot) valid = 0;
                        // Bottom-right vertex
                        if (tile1_br_rot != tile3_tr_rot) valid = 0;
                        // Bottom-left vertex
                        if (tile2_bl_rot != tile3_tl_rot) valid = 0;
                        // Internal vertex
                        if (tile0_br_rot != tile1_bl_rot || tile0_br_rot != tile2_tr_rot || tile0_br_rot != tile3_tl_rot) valid = 0;

                        if (valid) count <= count + 1;

                        // Increment counters
                        if (tile3_rot == 3) begin
                            tile3_rot <= 0;
                            if (tile3_idx == 3) begin
                                tile3_idx <= 0;
                                if (tile2_rot == 3) begin
                                    tile2_rot <= 0;
                                    if (tile2_idx == 3) begin
                                        tile2_idx <= 0;
                                        if (tile1_rot == 3) begin
                                            tile1_rot <= 0;
                                            if (tile1_idx == 3) begin
                                                tile1_idx <= 0;
                                                if (tile0_rot == 3) begin
                                                    tile0_rot <= 0;
                                                end else begin
                                                    tile0_rot <= tile0_rot + 1;
                                                end
                                            end else begin
                                                tile1_idx <= tile1_idx + 1;
                                            end
                                        end else begin
                                            tile1_rot <= tile1_rot + 1;
                                        end
                                    end else begin
                                        tile2_idx <= tile2_idx + 1;
                                    end
                                end else begin
                                    tile2_rot <= tile2_rot + 1;
                                end
                            end else begin
                                tile3_idx <= tile3_idx + 1;
                            end
                        end else begin
                            tile3_rot <= tile3_rot + 1;
                        end

                        cycle_count <= cycle_count + 1;
                    end
                end
                DONE: begin
                    if (!start) begin
                        state <= IDLE;
                        done <= 0;
                    end
                end
            endcase
        end
    end

endmodule