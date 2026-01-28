module arcade_expected_payout(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire data_valid,
    input wire signed [7:0] data_v,
    input wire [15:0] data_p0,
    input wire [15:0] data_p1,
    input wire [15:0] data_p2,
    input wire [15:0] data_p3,
    input wire [15:0] data_p4,
    input wire [8:0] data_idx,
    output reg [31:0] result,
    output reg done,
    output reg busy
);

    // Parameters
    localparam H = 526;  // Total holes
    localparam N = 32;   // Max rows
    localparam MAX_ITER = 1000;
    localparam THRESHOLD = 32'd256;  // Q16.16 threshold

    // States
    localparam [2:0] S_IDLE = 3'd0;
    localparam [2:0] S_LOAD = 3'd1;
    localparam [2:0] S_ITERATE = 3'd2;
    localparam [2:0] S_UPDATE = 3'd3;
    localparam [2:0] S_CHECK_ERROR = 3'd4;
    localparam [2:0] S_FINISH = 3'd5;

    // Storage (Dual-port BRAM)
    reg [31:0] E_ram [0:H-1];
    reg [31:0] v_ram [0:H-1];
    reg [15:0] p0_ram [0:H-1];
    reg [15:0] p1_ram [0:H-1];
    reg [15:0] p2_ram [0:H-1];
    reg [15:0] p3_ram [0:H-1];

    // Control signals
    reg [2:0] state;
    reg [9:0] iter_count;
    reg [8:0] hole_idx;
    reg [31:0] max_diff;
    reg [31:0] current_E;
    reg [31:0] new_E;
    reg [31:0] diff;
    reg [31:0] sum_prob_neighbors;
    reg [31:0] temp_product;

    // Neighbor indices
    reg [8:0] tl_idx;
    reg [8:0] tr_idx;
    reg [8:0] bl_idx;
    reg [8:0] br_idx;

    // Load counter
    reg [8:0] load_count;

    // Row/Col calculation
    reg [8:0] row_r;
    reg [8:0] col_c;

    // FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            iter_count <= 10'd0;
            hole_idx <= 9'd0;
            max_diff <= 32'd0;
            current_E <= 32'd0;
            new_E <= 32'd0;
            diff <= 32'd0;
            sum_prob_neighbors <= 32'd0;
            temp_product <= 32'd0;
            tl_idx <= 9'd0;
            tr_idx <= 9'd0;
            bl_idx <= 9'd0;
            br_idx <= 9'd0;
            load_count <= 9'd0;
            row_r <= 9'd0;
            col_c <= 9'd0;
            done <= 1'b0;
            busy <= 1'b0;
            result <= 32'd0;
        end else begin
            case (state)
                S_IDLE: begin
                    busy <= 1'b0;
                    done <= 1'b0;
                    if (data_valid) begin
                        state <= S_LOAD;
                        load_count <= 9'd0;
                    end else if (start) begin
                        state <= S_ITERATE;
                        iter_count <= 10'd0;
                        hole_idx <= 9'd0;
                        max_diff <= 32'd0;
                        busy <= 1'b1;
                    end
                end

                S_LOAD: begin
                    if (data_valid) begin
                        // Store data
                        v_ram[load_count] <= {{16'd0}, data_v};
                        p0_ram[load_count] <= data_p0;
                        p1_ram[load_count] <= data_p1;
                        p2_ram[load_count] <= data_p2;
                        p3_ram[load_count] <= data_p3;
                        // p4 not used in computation
                        load_count <= load_count + 9'd1;
                        if (load_count == H-1) begin
                            state <= S_IDLE;
                        end
                    end
                end

                S_ITERATE: begin
                    // Calculate row and column
                    row_r <= 9'd0;
                    col_c <= 9'd0;
                    if (hole_idx < 9'd526) begin
                        // Calculate row
                        reg [15:0] temp_val;
                        temp_val <= 8'd8 * hole_idx + 8'd1;
                        reg [15:0] sqrt_val;
                        integer i;
                        for (i = 0; i < 16; i = i + 1) begin
                            if ((i*i) <= temp_val && (i+1)*(i+1) > temp_val) begin
                                sqrt_val <= i;
                            end
                        end
                        row_r <= (sqrt_val - 8'd1) / 8'd2;
                        col_c <= hole_idx - (row_r * (row_r + 8'd1)) / 8'd2;

                        // Calculate neighbor indices
                        tl_idx <= (row_r > 0 && col_c > 0) ? 
                            (row_r - 1) * (row_r) / 2 + (col_c - 1) : 9'd0;
                        tr_idx <= (row_r > 0 && col_c < row_r - 1) ? 
                            (row_r - 1) * (row_r) / 2 + col_c : 9'd0;
                        bl_idx <= (row_r < N-1) ? 
                            (row_r + 1) * (row_r + 2) / 2 + col_c : 9'd0;
                        br_idx <= (row_r < N-1) ? 
                            (row_r + 1) * (row_r + 2) / 2 + col_c + 1 : 9'd0;

                        // Read current E
                        current_E <= E_ram[hole_idx];
                        state <= S_UPDATE;
                    end else begin
                        state <= S_CHECK_ERROR;
                    end
                end

                S_UPDATE: begin
                    // Read neighbor E values
                    reg [31:0] e_tl, e_tr, e_bl, e_br;
                    e_tl <= (tl_idx < H) ? E_ram[tl_idx] : 32'd0;
                    e_tr <= (tr_idx < H) ? E_ram[tr_idx] : 32'd0;
                    e_bl <= (bl_idx < H) ? E_ram[bl_idx] : 32'd0;
                    e_br <= (br_idx < H) ? E_ram[br_idx] : 32'd0;

                    // Compute sum of probabilities * neighbor E
                    sum_prob_neighbors <= 32'd0;
                    temp_product <= $signed(p0_ram[hole_idx]) * $signed(e_tl);
                    sum_prob_neighbors <= sum_prob_neighbors + temp_product;
                    temp_product <= $signed(p1_ram[hole_idx]) * $signed(e_tr);
                    sum_prob_neighbors <= sum_prob_neighbors + temp_product;
                    temp_product <= $signed(p2_ram[hole_idx]) * $signed(e_bl);
                    sum_prob_neighbors <= sum_prob_neighbors + temp_product;
                    temp_product <= $signed(p3_ram[hole_idx]) * $signed(e_br);
                    sum_prob_neighbors <= sum_prob_neighbors + temp_product;

                    // Compute new E
                    new_E <= v_ram[hole_idx] + sum_prob_neighbors;

                    // Update E in RAM
                    E_ram[hole_idx] <= new_E;

                    // Compute difference
                    diff <= (new_E > current_E) ? (new_E - current_E) : (current_E - new_E);
                    if (diff > max_diff) begin
                        max_diff <= diff;
                    end

                    // Move to next hole
                    hole_idx <= hole_idx + 9'd1;
                    state <= S_ITERATE;
                end

                S_CHECK_ERROR: begin
                    if (max_diff < THRESHOLD || iter_count == MAX_ITER-1) begin
                        state <= S_FINISH;
                    end else begin
                        iter_count <= iter_count + 10'd1;
                        hole_idx <= 9'd0;
                        max_diff <= 32'd0;
                        state <= S_ITERATE;
                    end
                end

                S_FINISH: begin
                    result <= E_ram[0];
                    done <= 1'b1;
                    busy <= 1'b0;
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule