module cluster_min #(
    parameter MAX_N = 16,
    parameter DATA_WIDTH = 8,
    parameter STATE_WIDTH = 4
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [DATA_WIDTH-1:0] a [0:MAX_N-1],
    input wire [DATA_WIDTH-1:0] b [0:MAX_N-1],
    input wire [MAX_N-1:0] c,
    input wire [3:0] n,
    output reg [DATA_WIDTH*2:0] result,
    output reg done
);

// State definitions
localparam [STATE_WIDTH-1:0] S_IDLE = 4'd0;
localparam [STATE_WIDTH-1:0] S_INIT = 4'd1;
localparam [STATE_WIDTH-1:0] S_PREPARE_PAIRS = 4'd2;
localparam [STATE_WIDTH-1:0] S_COMPUTE_PAIR = 4'd3;
localparam [STATE_WIDTH-1:0] S_LOOP_NON_VOTERS = 4'd4;
localparam [STATE_WIDTH-1:0] S_UPDATE_MIN = 4'd5;
localparam [STATE_WIDTH-1:0] S_DONE = 4'd6;

reg [STATE_WIDTH-1:0] state, next_state;

// Registers for data
reg [DATA_WIDTH-1:0] a_reg [0:MAX_N-1];
reg [DATA_WIDTH-1:0] b_reg [0:MAX_N-1];
reg [MAX_N-1:0] c_reg;
reg [3:0] n_reg;

// Registers for computation
reg [3:0] k;
reg [3:0] m;
reg [3:0] voter_idx [0:MAX_N-1];
reg [3:0] non_voter_idx [0:MAX_N-1];
reg [3:0] i, j;
reg [3:0] p;
reg signed [DATA_WIDTH-1:0] ax, ay, bx, by;
reg signed [DATA_WIDTH-1:0] dx, dy;
reg [DATA_WIDTH*2-1:0] dot_uw;
reg signed [DATA_WIDTH*2-1:0] dot_pu;
reg [DATA_WIDTH*2-1:0] count;
reg [DATA_WIDTH*2-1:0] cluster_size;
reg [DATA_WIDTH*2-1:0] min_cluster;

// State transition
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= S_IDLE;
    else state <= next_state;
end

// Next state logic
always @(*) begin
    next_state = state;
    case (state)
        S_IDLE: if (start) next_state = S_INIT;
        S_INIT: next_state = S_PREPARE_PAIRS;
        S_PREPARE_PAIRS: next_state = S_COMPUTE_PAIR;
        S_COMPUTE_PAIR: next_state = S_LOOP_NON_VOTERS;
        S_LOOP_NON_VOTERS: begin
            if (p < m-1) next_state = S_LOOP_NON_VOTERS;
            else next_state = S_UPDATE_MIN;
        end
        S_UPDATE_MIN: begin
            if (j < k-1) next_state = S_COMPUTE_PAIR;
            else if (i < k-1) next_state = S_COMPUTE_PAIR;
            else next_state = S_DONE;
        end
        S_DONE: next_state = S_IDLE;
        default: next_state = S_IDLE;
    endcase
end

// Datapath
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        done <= 1'b0;
        result <= {DATA_WIDTH*2{1'b0}};
        k <= 4'd0;
        m <= 4'd0;
        i <= 4'd0;
        j <= 4'd0;
        p <= 4'd0;
        min_cluster <= {DATA_WIDTH*2{1'b0}};
        count <= {DATA_WIDTH*2{1'b0}};
        cluster_size <= {DATA_WIDTH*2{1'b0}};
        integer idx;
        for (idx = 0; idx < MAX_N; idx = idx + 1) begin
            voter_idx[idx] <= 4'd0;
            non_voter_idx[idx] <= 4'd0;
            a_reg[idx] <= {DATA_WIDTH{1'b0}};
            b_reg[idx] <= {DATA_WIDTH{1'b0}};
        end
        c_reg <= {MAX_N{1'b0}};
        n_reg <= 4'd0;
    end else begin
        case (state)
            S_IDLE: begin
                done <= 1'b0;
                if (start) begin
                    integer idx;
                    for (idx = 0; idx < MAX_N; idx = idx + 1) begin
                        a_reg[idx] <= a[idx];
                        b_reg[idx] <= b[idx];
                    end
                    c_reg <= c;
                    n_reg <= n;
                end
            end

            S_INIT: begin
                k <= 4'd0;
                m <= 4'd0;
                integer idx;
                for (idx = 0; idx < n_reg; idx = idx + 1) begin
                    if (c_reg[idx]) begin
                        voter_idx[k] <= idx;
                        k <= k + 4'd1;
                    end else begin
                        non_voter_idx[m] <= idx;
                        m <= m + 4'd1;
                    end
                end
                min_cluster <= k;
            end

            S_PREPARE_PAIRS: begin
                i <= 4'd0;
                j <= 4'd0;
            end

            S_COMPUTE_PAIR: begin
                ax <= a_reg[voter_idx[i]];
                ay <= b_reg[voter_idx[i]];
                bx <= a_reg[voter_idx[j]];
                by <= b_reg[voter_idx[j]];
                dx <= bx - ax;
                dy <= by - ay;
                dot_uw <= (bx - ax)*(bx - ax) + (by - ay)*(by - ay);
                count <= 4'd0;
                p <= 4'd0;
            end

            S_LOOP_NON_VOTERS: begin
                if (p < m) begin
                    dot_pu <= (a_reg[non_voter_idx[p]] - ax)*dx + (b_reg[non_voter_idx[p]] - ay)*dy;
                    if (dot_pu > 0 && dot_pu < dot_uw) count <= count + 4'd1;
                    p <= p + 4'd1;
                end
            end

            S_UPDATE_MIN: begin
                cluster_size <= k + count;
                if (k + count < min_cluster) min_cluster <= k + count;
                if (j < k-1) j <= j + 4'd1;
                else begin
                    j <= 4'd0;
                    if (i < k-1) i <= i + 4'd1;
                end
            end

            S_DONE: begin
                result <= min_cluster;
                done <= 1'b1;
            end
        endcase
    end
end

endmodule