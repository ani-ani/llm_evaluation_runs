module max_clique #(
    parameter N = 4,
    parameter DATA_WIDTH = 16,
    parameter MASK_WIDTH = N,
    parameter SIZE_WIDTH = 3
)(
    input clk,
    input rst_n,
    input start,
    input [DATA_WIDTH-1:0] d,
    input [DATA_WIDTH-1:0] x0, x1, x2, x3,
    input [DATA_WIDTH-1:0] y0, y1, y2, y3,
    input [2:0] num_sensors,
    output reg [SIZE_WIDTH-1:0] max_size,
    output reg [MASK_WIDTH-1:0] subset_mask,
    output reg done
);

// Internal coordinate registers
reg [DATA_WIDTH-1:0] x[0:N-1];
reg [DATA_WIDTH-1:0] y[0:N-1];

// Adjacency matrix
reg adj[0:N-1][0:N-1];

// State machine states
localparam [2:0]
    IDLE        = 3'd0,
    COMPUTE_ADJ = 3'd1,
    INIT_ENUM   = 3'd2,
    CHECK_SUBSET = 3'd3,
    DONE_STATE  = 3'd4;

reg [2:0] state, next_state;

// Enumeration registers
reg [MASK_WIDTH-1:0] mask, next_mask;
reg [SIZE_WIDTH-1:0] best_size, next_best_size;
reg [MASK_WIDTH-1:0] best_mask, next_best_mask;
reg [2:0] pair_index, next_pair_index;
reg clique_ok, next_clique_ok;
reg [DATA_WIDTH*2-1:0] d_sq, next_d_sq;

// Pair index to sensor indices
data_file.sv
wire [1:0] i_idx, j_idx;
assign i_idx = (pair_index == 3'd0) ? 2'd0 :
               (pair_index == 3'd1) ? 2'd0 :
               (pair_index == 3'd2) ? 2'd0 :
               (pair_index == 3'd3) ? 2'd1 :
               (pair_index == 3'd4) ? 2'd1 : 2'd2;
assign j_idx = (pair_index == 3'd0) ? 2'd1 :
               (pair_index == 3'd1) ? 2'd2 :
               (pair_index == 3'd2) ? 2'd3 :
               (pair_index == 3'd3) ? 2'd2 :
               (pair_index == 3'd4) ? 2'd3 : 2'd3;

// Distance calculation
wire [DATA_WIDTH-1:0] dx = (x[i_idx] > x[j_idx]) ? (x[i_idx] - x[j_idx]) : (x[j_idx] - x[i_idx]);
wire [DATA_WIDTH-1:0] dy = (y[i_idx] > y[j_idx]) ? (y[i_idx] - y[j_idx]) : (y[j_idx] - y[i_idx]);
wire [DATA_WIDTH*2-1:0] dist_sq = dx * dx + dy * dy;

// Population count (combinational)
wire [SIZE_WIDTH-1:0] popcount = mask[0] + mask[1] + mask[2] + mask[3];

// Next state logic
always @(*) begin
    next_state = state;
    next_mask = mask;
    next_best_size = best_size;
    next_best_mask = best_mask;
    next_pair_index = pair_index;
    next_clique_ok = clique_ok;
    next_d_sq = d_sq;

    case (state)
        IDLE: begin
            if (start) begin
                next_d_sq = d * d;
                next_pair_index = 3'd0;
                next_state = COMPUTE_ADJ;
            end
        end

        COMPUTE_ADJ: begin
            if (pair_index < 3'd5) begin
                next_pair_index = pair_index + 3'd1;
            end else begin
                next_state = INIT_ENUM;
                next_mask = {MASK_WIDTH{1'b0}};
            end
        end

        INIT_ENUM: begin
            next_best_size = 3'd0;
            next_best_mask = {MASK_WIDTH{1'b0}};
            next_pair_index = 3'd0;
            next_clique_ok = 1'b1;
            next_mask = {MASK_WIDTH{1'b0}};
            next_state = CHECK_SUBSET;
        end

        CHECK_SUBSET: begin
            if (pair_index < 3'd6) begin
                if (mask[i_idx] && mask[j_idx]) begin
                    if (i_idx < num_sensors && j_idx < num_sensors) begin
                        if (!adj[i_idx][j_idx]) begin
                            next_clique_ok = 1'b0;
                        end
                    end
                end
                next_pair_index = pair_index + 3'd1;
            end else begin
                if (clique_ok) begin
                    if (popcount > best_size) begin
                        next_best_size = popcount;
                        next_best_mask = mask;
                    end
                end
                
                if (mask != (1 << N) - 1) begin
                    next_mask = mask + 1'b1;
                    next_pair_index = 3'd0;
                    next_clique_ok = 1'b1;
                end else begin
                    next_state = DONE_STATE;
                end
            end
        end

        DONE_STATE: begin
            next_state = IDLE;
        end

        default: next_state = IDLE;
    endcase
end

// Sequential logic
always @(posedge clk or negedge rst_n) begin
    integer i, j;
    if (!rst_n) begin
        state <= IDLE;
        mask <= {MASK_WIDTH{1'b0}};
        best_size <= 3'd0;
        best_mask <= {MASK_WIDTH{1'b0}};
        pair_index <= 3'd0;
        clique_ok <= 1'b1;
        d_sq <= {DATA_WIDTH*2{1'b0}};
        done <= 1'b0;
        max_size <= 3'd0;
        subset_mask <= {MASK_WIDTH{1'b0}};
        for (i = 0; i < N; i = i+1) begin
            x[i] <= {DATA_WIDTH{1'b0}};
            y[i] <= {DATA_WIDTH{1'b0}};
            for (j = 0; j < N; j = j+1) begin
                adj[i][j] <= 1'b0;
            end
        end
    end else begin
        state <= next_state;
        mask <= next_mask;
        best_size <= next_best_size;
        best_mask <= next_best_mask;
        pair_index <= next_pair_index;
        clique_ok <= next_clique_ok;
        d_sq <= next_d_sq;
        
        case (state)
            COMPUTE_ADJ: begin
                if (pair_index < 3'd6) begin
                    if (i_idx < num_sensors && j_idx < num_sensors) begin
                        adj[i_idx][j_idx] <= (dist_sq <= d_sq);
                        adj[j_idx][i_idx] <= (dist_sq <= d_sq);
                    end else begin
                        adj[i_idx][j_idx] <= 1'b0;
                        adj[j_idx][i_idx] <= 1'b0;
                    end
                end
            end

            DONE_STATE: begin
                done <= 1'b1;
                max_size <= best_size;
                subset_mask <= best_mask;
            end

            default: done <= 1'b0;
        endcase

        if (state == IDLE && start) begin
            x[0] <= x0;
            x[1] <= x1;
            x[2] <= x2;
            x[3] <= x3;
            y[0] <= y0;
            y[1] <= y1;
            y[2] <= y2;
            y[3] <= y3;
        end
    end
end

endmodule