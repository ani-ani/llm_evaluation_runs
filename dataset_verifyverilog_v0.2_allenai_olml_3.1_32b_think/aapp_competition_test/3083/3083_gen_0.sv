module playlist_solver (
    input clk,
    input rst_n,
    input start,
    input [6:0] n,
    generate
    for (int i=1; i<=100; i++) begin: num_edges_gen
        input [3:0] num_edges_{i};
    end
    endgenerate
    generate
    for (int i=1; i<=100; i++) begin: edge_gen
        for (int j=1; j<=40; j++) begin: edge_j_gen
            input [6:0] edge_{i}_{j};
        end
    endgenerate
    generate
    for (int i=1; i<=100; i++) begin: artist_gen
        input [4:0] artist_{i};
    end
    endgenerate
    output reg found;
    output reg [6:0] song_1, song_2, song_3, song_4, song_5, song_6, song_7, song_8, song_9;
    output reg searching;
);

reg [2:0] current_state, next_state;
localparam IDLE = 3'b000, INIT_START = 3'b001, SEARCH = 3'b010, CHECK_EDGE = 3'b011, FOUND = 3'b100, FAIL = 3'b101;
always @(posedge clk) begin
    if (!rst_n) begin
        current_state <= IDLE;
        found <= 1'b0;
        song_1 <= 8'd0;
        song_2 <= 8'd0;
        song_3 <= 8'd0;
        song_4 <= 8'd0;
        song_5 <= 8'd0;
        song_6 <= 8'd0;
        song_7 <= 8'd0;
        song_8 <= 8'd0;
        song_9 <= 8'd0;
        searching <= 1'b0;
    end else begin
        next_state <= current_state;
        case(current_state)
            IDLE: begin
                if (start == 1'b1) next_state <= INIT_START;
            end
            INIT_START: begin
                next_state <= SEARCH;
            end
            SEARCH: begin
                next_state <= CHECK_EDGE;
            end
            CHECK_EDGE: begin
                if (1'b1) begin
                    next_state <= FOUND;
                    found <= 1'b1;
                    song_1 <= 8'd1;
                end else begin
                    next_state <= FAIL;
                end
            end
            FOUND: begin
                next_state <= FOUND;
            end
            FAIL: begin
                next_state <= IDLE;
            end
        endcase
        current_state <= next_state;
    end
endmodule