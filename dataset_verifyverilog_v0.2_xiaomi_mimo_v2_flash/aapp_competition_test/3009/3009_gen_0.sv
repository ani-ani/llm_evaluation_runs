module energy_balancer (
    input clk,
    input rst_n,
    input start,
    input [7:0] coord_x [0:7],
    input [7:0] coord_y [0:7],
    input [31:0] energy [0:7],
    input [2:0] num_lamps,
    output reg [31:0] min_perimeter,
    output reg valid,
    output reg impossible
);

    localparam IDLE = 4'd0;
    localparam PRECOMP = 4'd1;
    localparam CHECK = 4'd2;
    localparam SORT = 4'd3;
    localparam HULL = 4'd4;
    localparam DIST = 4'd5;
    localparam SQRT = 4'd6;
    localparam ADD = 4'd7;
    localparam CMP = 4'd8;
    localparam DONE = 4'd9;

    reg [3:0] state, n_state;

    reg [31:0] tot_e;
    reg [31:0] tgt_e;
    reg [31:0] cur_sub_e;
    reg [7:0] cur_sub;
    reg [2:0] sub_cnt;
    reg [2:0] l_idx;

    reg [7:0] pts_x [0:7];
    reg [7:0] pts_y [0:7];
    reg [2:0] pt_cnt;
    
    reg [2:0] s_i, s_j;
    
    reg [7:0] st_x [0:7];
    reg [7:0] st_y [0:7];
    reg [2:0] st_ptr;
    reg [2:0] h_idx;
    
    reg [2:0] d_idx;
    reg [31:0] perim;
    
    reg [31:0] dx, dy, d2;
    reg [63:0] rad;
    reg [63:0] rem;
    reg [31:0] rt;
    reg [4:0] s_iter;

    wire signed [31:0] cross = (st_x[st_ptr-1] - st_x[st_ptr-2]) * (pts_y[h_idx] - st_y[st_ptr-2]) - 
                               (st_y[st_ptr-1] - st_y[st_ptr-2]) * (pts_x[h_idx] - st_x[st_ptr-2]);

    always @(*) begin
        n_state = state;
        case (state)
            IDLE: if (start) n_state = PRECOMP;
            PRECOMP: n_state = CHECK;
            CHECK: begin
                if (cur_sub_e == tgt_e && l_idx >= 2 && l_idx < num_lamps) n_state = SORT;
                else if (cur_sub >= (8'b1 << num_lamps)) n_state = DONE;
                else n_state = CHECK;
            end
            SORT: if (s_j == 0) n_state = HULL; else n_state = SORT;
            HULL: if (h_idx >= pt_cnt) n_state = (st_ptr < 2) ? CMP : DIST; else n_state = HULL;
            DIST: n_state = SQRT;
            SQRT: if (s_iter == 31) n_state = ADD; else n_state = SQRT;
            ADD: if (d_idx >= st_ptr) n_state = CMP; else n_state = DIST;
            CMP: n_state = CHECK;
            DONE: n_state = DONE;
            default: n_state = IDLE;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            min_perimeter <= 32'hFFFF_FFFF;
            valid <= 0;
            impossible <= 0;
        end else begin
            state <= n_state;
            case (state)
                IDLE: begin
                    if (start) begin
                        cur_sub <= 1;
                        min_perimeter <= 32'hFFFF_FFFF;
                        valid <= 0;
                        impossible <= 0;
                    end
                end
                PRECOMP: begin
                    tot_e <= 0;
                    for (integer i = 0; i < 8; i++) if (i < num_lamps) tot_e <= tot_e + energy[i];
                end
                CHECK: begin
                    tgt_e <= tot_e >> 1;
                    if (cur_sub_e == tgt_e && l_idx >= 2 && l_idx < num_lamps) begin
                        // Valid subset found, copy points
                        pt_cnt <= 0;
                        for (integer k = 0; k < 8; k++) begin
                            if (cur_sub[k] && k < num_lamps) begin
                                pts_x[pt_cnt] <= coord_x[k];
                                pts_y[pt_cnt] <= coord_y[k];
                                pt_cnt <= pt_cnt + 1;
                            end
                        end
                        s_i <= l_idx; 
                        s_j <= l_idx - 1;
                    end else begin
                        if (cur_sub < (8'b1 << num_lamps)) cur_sub <= cur_sub + 1;
                    end
                    // Calculate next subset energy for next cycle (optimistic)
                    // Note: The logic relies on 'cur_sub_e' being computed combinationally or latched.
                    // To be safe, we compute it here for the *current* cur_sub.
                    // But we increment cur_sub at end of this state logic if not valid.
                    // Let's compute energy of cur_sub.
                    cur_sub_e <= 0; l_idx <= 0;
                    for (integer k = 0; k < 8; k++) begin
                        if (cur_sub[k] && k < num_lamps) begin
                             cur_sub_e <= cur_sub_e + energy[k];
                             l_idx <= l_idx + 1;
                        end
                    end
                end
                SORT: begin
                    if (s_j > 0) begin
                        if (pts_x[s_j-1] > pts_x[s_j] || (pts_x[s_j-1] == pts_x[s_j] && pts_y[s_j-1] > pts_y[s_j])) begin
                            pts_x[s_j-1] <= pts_x[s_j]; pts_y[s_j-1] <= pts_y[s_j];
                            pts_x[s_j] <= pts_x[s_j-1]; pts_y[s_j] <= pts_y[s_j-1];
                        end
                        s_j <= s_j - 1;
                    end else begin
                        if (s_i > 1) begin s_i <= s_i - 1; s_j <= s_i - 1; end
                        else begin st_ptr <= 0; h_idx <= 0; end
                    end
                end
                HULL: begin
                    if (st_ptr >= 2 && cross <= 0) begin
                        st_ptr <= st_ptr - 1;
                    end else begin
                        st_x[st_ptr] <= pts_x[h_idx]; st_y[st_ptr] <= pts_y[h_idx];
                        st_ptr <= st_ptr + 1;
                        h_idx <= h_idx + 1;
                    end
                end
                DIST: begin
                    // Setup dx, dy
                    if (d_idx < st_ptr - 1) begin
                        dx <= (st_x[d_idx] > st_x[d_idx+1]) ? st_x[d_idx] - st_x[d_idx+1] : st_x[d_idx+1] - st_x[d_idx];
                        dy <= (st_y[d_idx] > st_y[d_idx+1]) ? st_y[d_idx] - st_y[d_idx+1] : st_y[d_idx+1] - st_y[d_idx];
                    end else begin
                        dx <= (st_x[st_ptr-1] > st_x[0]) ? st_x[st_ptr-1] - st_x[0] : st_x[0] - st_x[st_ptr-1];
                        dy <= (st_y[st_ptr-1] > st_y[0]) ? st_y[st_ptr-1] - st_y[0] : st_y[0] - st_y[st_ptr-1];
                    end
                    // Reset sqrt
                    s_iter <= 0; rad <= 0; rem <= 0; rt <= 0;
                end
                SQRT: begin
                    // rad = (dx^2 + dy^2) << 32
                    if (s_iter == 0) begin
                        rad <= { (dx*dx + dy*dy), 32'b0 };
                    end else begin
                        {rem, rad} <= {rem[61:0], rad[63:62]};
                        rt <= rt << 1;
                        if (rem >= (rt << 1) + 1) begin
                            rem <= rem - ((rt << 1) + 1);
                            rt <= (rt << 1) + 1;
                        end
                    end
                    s_iter <= s_iter + 1;
                end
                ADD: begin
                    perim <= perim + rt;
                    d_idx <= d_idx + 1;
                end
                CMP: begin
                    if (perim < min_perimeter) min_perimeter <= perim;
                    perim <= 0;
                    d_idx <= 0;
                end
                DONE: begin
                    valid <= 1;
                    impossible <= (min_perimeter == 32'hFFFF_FFFF);
                end
            endcase
        end
    end
endmodule