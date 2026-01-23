module maze_equivalence (
    input clk,
    input rst_n,
    input start,
    input [6:0] num_rooms,
    input [2:0] room_degree [0:15],
    input [6:0] room_neighbors [0:15][0:7],
    output reg [2:0] group_id [0:15],
    output reg [3:0] num_groups,
    output reg done,
    output reg none
);

reg [31:0] current_label [0:15];
reg [31:0] next_label [0:15];
reg [15:0] iter_count;
reg [2:0] state;
reg [6:0] reg_num_rooms;
reg [2:0] reg_room_degree [0:15];
reg [6:0] reg_room_neighbors [0:15][0:7];
reg [2:0] group_id_reg [0:15];
reg [3:0] num_groups_reg;
reg done_reg;
reg none_reg;

localparam IDLE = 3'd0;
localparam INIT = 3'd1;
localparam ITERATE = 3'd2;
localparam FORM_GROUPS = 3'd3;
localparam DONE = 3'd4;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        iter_count <= 16;
        reg_num_rooms <= 0;
        reg_room_degree <= 0;
        reg_room_neighbors <= 0;
        current_label <= 0;
        next_label <= 0;
        group_id_reg <= 0;
        num_groups_reg <= 0;
        done_reg <= 0;
        none_reg <= 0;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    reg_num_rooms <= num_rooms;
                    reg_room_degree <= room_degree;
                    reg_room_neighbors <= room_neighbors;
                    state <= INIT;
                end
            end
            INIT: begin
                for (int i=0; i<16; i++) begin
                    if (i < reg_num_rooms) begin
                        current_label[i] <= {29{0}, reg_room_degree[i]};
                    end
                end
                iter_count <= 16;
                state <= ITERATE;
            end
            ITERATE: begin
                reg [31:0] sum;
                for (int i=0; i<16; i++) begin
                    sum = 0;
                    for (int j=0; j<8; j++) begin
                        if (reg_room_neighbors[i][j] != 0) begin
                            sum += current_label[reg_room_neighbors[i][j]];
                        end
                    end
                    next_label[i] = current_label[i] ^ sum;
                end
                current_label <= next_label;
                iter_count <= iter_count - 1;
                if (iter_count == 0) begin
                    state <= FORM_GROUPS;
                end
            end
            FORM_GROUPS: begin
                int group_count = 0;
                for (int i=0; i<reg_num_rooms; i++) begin
                    int cnt = 0;
                    for (int j=0; j<reg_num_rooms; j++) begin
                        if (i != j && current_label[i] == current_label[j]) begin
                            cnt++;
                        end
                    end
                    if (cnt > 0) begin
                        group_count++;
                    end
                end
                num_groups_reg <= group_count;
                none_reg <= (group_count == 0);
                done_reg <= 1;
                state <= DONE;
            end
            DONE: begin
                done_reg <= 1;
            end
        endcase
    end
end

assign group_id = group_id_reg;
assign num_groups = num_groups_reg;
assign done = done_reg;
assign none = none_reg;

endmodule