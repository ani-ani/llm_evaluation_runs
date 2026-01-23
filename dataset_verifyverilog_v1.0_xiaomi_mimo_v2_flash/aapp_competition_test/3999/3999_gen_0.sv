module cube_counter (
    input wire clk,
    input wire reset,
    input wire start,
    input wire [39:0] tile_0, tile_1, tile_2, tile_3,
    input wire [39:0] tile_4, tile_5, tile_6, tile_7,
    output reg done,
    output reg [63:0] count
);

parameter N = 8;
parameter DATA_WIDTH = 10;
parameter MAX_CANONICAL_TYPES = 8;

localparam [3:0] S_IDLE = 4'd0;
localparam [3:0] S_COMPUTE_CANONICAL = 4'd1;
localparam [3:0] S_BUILD_TABLE = 4'd2;
localparam [3:0] S_MAIN_LOOP_I = 4'd3;
localparam [3:0] S_DECREMENT_I = 4'd4;
localparam [3:0] S_MAIN_LOOP_J = 4'd5;
localparam [3:0] S_DECREMENT_J = 4'd6;
localparam [3:0] S_ROTATION_LOOP = 4'd7;
localparam [3:0] S_GET_ROTATED_GG = 4'd8;
localparam [3:0] S_FORM_TUPLES = 4'd9;
localparam [3:0] S_LOOKUP_TUPLES = 4'd10;
localparam [3:0] S_COMPUTE_PRODUCT = 4'd11;
localparam [3:0] S_ADD_TO_COUNT = 4'd12;
localparam [3:0] S_DONE = 4'd13;

reg [3:0] state;

reg [DATA_WIDTH-1:0] tile_colors [0:N-1][0:3];
reg [DATA_WIDTH-1:0] canon_colors [0:N-1][0:3];
reg [2:0] canon_idx [0:N-1];

reg [DATA_WIDTH-1:0] canon_types [0:MAX_CANONICAL_TYPES-1][0:3];
reg [3:0] dd [0:MAX_CANONICAL_TYPES-1];
reg [1:0] cc [0:MAX_CANONICAL_TYPES-1];
reg [2:0] num_canon_types;

reg [2:0] i_idx;
reg [3:0] j_idx;
reg [1:0] rot;
reg [1:0] tuple_idx;
reg [2:0] tile_idx_for_canon;

reg [3:0] dd_temp [0:MAX_CANONICAL_TYPES-1];
reg [3:0] product_temp;
reg [63:0] total_count;

reg [DATA_WIDTH-1:0] tuple_colors [0:3];
reg tuple_found;

reg [DATA_WIDTH-1:0] gg_rot [0:3];

integer k;

always @(posedge clk or posedge reset) begin
    if (reset) begin
        state <= S_IDLE;
        done <= 1'b0;
        count <= 64'd0;
        total_count <= 64'd0;
        num_canon_types <= 3'd0;
        tile_idx_for_canon <= 3'd0;
        i_idx <= 3'd0;
        j_idx <= 4'd0;
        rot <= 2'd0;
        tuple_idx <= 2'd0;
        for (k = 0; k < MAX_CANONICAL_TYPES; k = k + 1) begin
            dd[k] <= 4'd0;
            cc[k] <= 2'd0;
        end
        for (k = 0; k < N; k = k + 1) begin
            canon_idx[k] <= 3'd0;
        end
    end else begin
        case (state)
            S_IDLE: begin
                done <= 1'b0;
                if (start) begin
                    tile_colors[0][0] <= tile_0[9:0];
                    tile_colors[0][1] <= tile_0[19:10];
                    tile_colors[0][2] <= tile_0[29:20];
                    tile_colors[0][3] <= tile_0[39:30];
                    tile_colors[1][0] <= tile_1[9:0];
                    tile_colors[1][1] <= tile_1[19:10];
                    tile_colors[1][2] <= tile_1[29:20];
                    tile_colors[1][3] <= tile_1[39:30];
                    tile_colors[2][0] <= tile_2[9:0];
                    tile_colors[2][1] <= tile_2[19:10];
                    tile_colors[2][2] <= tile_2[29:20];
                    tile_colors[2][3] <= tile_2[39:30];
                    tile_colors[3][0] <= tile_3[9:0];
                    tile_colors[3][1] <= tile_3[19:10];
                    tile_colors[3][2] <= tile_3[29:20];
                    tile_colors[3][3] <= tile_3[39:30];
                    tile_colors[4][0] <= tile_4[9:0];
                    tile_colors[4][1] <= tile_4[19:10];
                    tile_colors[4][2] <= tile_4[29:20];
                    tile_colors[4][3] <= tile_4[39:30];
                    tile_colors[5][0] <= tile_5[9:0];
                    tile_colors[5][1] <= tile_5[19:10];
                    tile_colors[5][2] <= tile_5[29:20];
                    tile_colors[5][3] <= tile_5[39:30];
                    tile_colors[6][0] <= tile_6[9:0];
                    tile_colors[6][1] <= tile_6[19:10];
                    tile_colors[6][2] <= tile_6[29:20];
                    tile_colors[6][3] <= tile_6[39:30];
                    tile_colors[7][0] <= tile_7[9:0];
                    tile_colors[7][1] <= tile_7[19:10];
                    tile_colors[7][2] <= tile_7[29:20];
                    tile_colors[7][3] <= tile_7[39:30];
                    state <= S_COMPUTE_CANONICAL;
                    tile_idx_for_canon <= 3'd0;
                    num_canon_types <= 3'd0;
                end
            end

            S_COMPUTE_CANONICAL: begin
                if (tile_idx_for_canon < N) begin
                    for (k = 0; k < 4; k = k + 1) begin
                        canon_colors[tile_idx_for_canon][k] <= tile_colors[tile_idx_for_canon][k];
                    end
                    canon_idx[tile_idx_for_canon] <= num_canon_types;
                    for (k = 0; k < 4; k = k + 1) begin
                        canon_types[num_canon_types][k] <= tile_colors[tile_idx_for_canon][k];
                    end
                    num_canon_types <= num_canon_types + 3'd1;
                    tile_idx_for_canon <= tile_idx_for_canon + 3'd1;
                end else begin
                    state <= S_BUILD_TABLE;
                end
            end

            S_BUILD_TABLE: begin
                for (k = 0; k < MAX_CANONICAL_TYPES; k = k + 1) begin
                    dd[k] <= 4'd0;
                    cc[k] <= 2'd0;
                end
                for (k = 0; k < N; k = k + 1) begin
                    dd[canon_idx[k]] <= dd[canon_idx[k]] + 4'd1;
                end
                i_idx <= 3'd0;
                state <= S_MAIN_LOOP_I;
            end

            S_MAIN_LOOP_I: begin
                if (i_idx < N) begin
                    state <= S_DECREMENT_I;
                end else begin
                    state <= S_DONE;
                end
            end

            S_DECREMENT_I: begin
                dd[canon_idx[i_idx]] <= dd[canon_idx[i_idx]] - 4'd1;
                j_idx <= {1'b0, i_idx} + 4'd1;
                state <= S_MAIN_LOOP_J;
            end

            S_MAIN_LOOP_J: begin
                if (j_idx < N) begin
                    state <= S_DECREMENT_J;
                end else begin
                    dd[canon_idx[i_idx]] <= dd[canon_idx[i_idx]] + 4'd1;
                    i_idx <= i_idx + 3'd1;
                    state <= S_MAIN_LOOP_I;
                end
            end

            S_DECREMENT_J: begin
                dd[canon_idx[j_idx]] <= dd[canon_idx[j_idx]] - 4'd1;
                rot <= 2'd0;
                state <= S_ROTATION_LOOP;
            end

            S_ROTATION_LOOP: begin
                if (rot < 4) begin
                    state <= S_GET_ROTATED_GG;
                end else begin
                    dd[canon_idx[j_idx]] <= dd[canon_idx[j_idx]] + 4'd1;
                    j_idx <= j_idx + 4'd1;
                    state <= S_MAIN_LOOP_J;
                end
            end

            S_GET_ROTATED_GG: begin
                if (rot == 2'd0) begin
                    gg_rot[0] <= tile_colors[j_idx][0];
                    gg_rot[1] <= tile_colors[j_idx][1];
                    gg_rot[2] <= tile_colors[j_idx][2];
                    gg_rot[3] <= tile_colors[j_idx][3];
                end else if (rot == 2'd1) begin
                    gg_rot[0] <= tile_colors[j_idx][1];
                    gg_rot[1] <= tile_colors[j_idx][2];
                    gg_rot[2] <= tile_colors[j_idx][3];
                    gg_rot[3] <= tile_colors[j_idx][0];
                end else if (rot == 2'd2) begin
                    gg_rot[0] <= tile_colors[j_idx][2];
                    gg_rot[1] <= tile_colors[j_idx][3];
                    gg_rot[2] <= tile_colors[j_idx][0];
                    gg_rot[3] <= tile_colors[j_idx][1];
                end else begin
                    gg_rot[0] <= tile_colors[j_idx][3];
                    gg_rot[1] <= tile_colors[j_idx][0];
                    gg_rot[2] <= tile_colors[j_idx][1];
                    gg_rot[3] <= tile_colors[j_idx][2];
                end
                state <= S_FORM_TUPLES;
                tuple_idx <= 2'd0;
            end

            S_FORM_TUPLES: begin
                tuple_found <= 1'b0;
                if (tuple_idx == 2'd0) begin
                    tuple_colors[0] <= tile_colors[i_idx][0];
                    tuple_colors[1] <= tile_colors[i_idx][1];
                    tuple_colors[2] <= tile_colors[i_idx][2];
                    tuple_colors[3] <= tile_colors[i_idx][3];
                end else if (tuple_idx == 2'd1) begin
                    tuple_colors[0] <= tile_colors[i_idx][2];
                    tuple_colors[1] <= tile_colors[i_idx][1];
                    tuple_colors[2] <= tile_colors[i_idx][0];
                    tuple_colors[3] <= tile_colors[i_idx][3];
                end else begin
                    tuple_colors[0] <= tile_colors[i_idx][1];
                    tuple_colors[1] <= tile_colors[i_idx][0];
                    tuple_colors[2] <= tile_colors[i_idx][3];
                    tuple_colors[3] <= tile_colors[i_idx][2];
                end
                state <= S_LOOKUP_TUPLES;
            end

            S_LOOKUP_TUPLES: begin
                for (k = 0; k < MAX_CANONICAL_TYPES && !tuple_found; k = k + 1) begin
                    if (k < num_canon_types &&
                        canon_types[k][0] == tuple_colors[0] &&
                        canon_types[k][1] == tuple_colors[1] &&
                        canon_types[k][2] == tuple_colors[2] &&
                        canon_types[k][3] == tuple_colors[3]) begin
                        tuple_found <= 1'b1;
                        cc[k] <= cc[k] + 2'd1;
                    end
                end
                if (tuple_found) begin
                    state <= S_COMPUTE_PRODUCT;
                end else begin
                    state <= S_ADD_TO_COUNT;
                end
            end

            S_COMPUTE_PRODUCT: begin
                for (k = 0; k < MAX_CANONICAL_TYPES && k < num_canon_types; k = k + 1) begin
                    dd_temp[k] <= dd[k];
                end
                state <= S_ADD_TO_COUNT;
            end

            S_ADD_TO_COUNT: begin
                if (tuple_found) begin
                    product_temp <= 4'd1;
                    for (k = 0; k < MAX_CANONICAL_TYPES && k < num_canon_types; k = k + 1) begin
                        if (cc[k] == 2'd0) begin
                            product_temp <= product_temp * (dd_temp[k] + 4'd1);
                        end else begin
                            product_temp <= product_temp * dd_temp[k];
                        end
                    end
                    total_count <= total_count + {60'd0, product_temp};
                end
                tuple_idx <= tuple_idx + 2'd1;
                if (tuple_idx < 2'd2) begin
                    state <= S_FORM_TUPLES;
                end else begin
                    state <= S_ROTATION_LOOP;
                    rot <= rot + 2'd1;
                end
            end

            S_DONE: begin
                count <= total_count;
                done <= 1'b1;
                if (!start) begin
                    state <= S_IDLE;
                end
            end

            default: state <= S_IDLE;
        endcase
    end
end

endmodule