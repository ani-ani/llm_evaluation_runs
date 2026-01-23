module star_wars_movies (input clk, input rst_n, input start, input [1:0] query_type, input [7:0] query_value, output reg [7:0] result, output reg done);
parameter MAX_MOVIES =16;
parameter MAX_QUERIES =256;

reg [7:0] movies [MAX_MOVIES];
reg [7:0] n;
reg [1:0] state;
localparam IDLE = 2'd0;
localparam PROCESS_QUERY = 2'd1;
localparam INSERT = 2'd2;
localparam SHIFT = 2'd3;
localparam DONE_STATE = 2'd4;

reg [7:0] q_type_reg;
reg [7:0] q_value_reg;
reg [7:0] shift_count;
reg [7:0] shift_index;
reg [7:0] next_idx_reg;
reg [3:0] target_reg;
reg [7:0] result;

assign done = (state == IDLE || state == DONE_STATE);

always_ff @(posedge clk)
    if (!rst_n) begin
        n <= 0;
        state <= IDLE;
        q_type_reg <=0;
        q_value_reg <=0;
        shift_count <=0;
        shift_index <=0;
        next_idx_reg <=0;
        target_reg <=0;
        result <=0;
    end
    else begin
        case (state)
            IDLE: begin
                if (start && done) begin
                    state <= PROCESS_QUERY;
                    q_type_reg <= query_type;
                    q_value_reg <= query_value;
                end
            end
            PROCESS_QUERY: begin
                if (q_type_reg ==1) begin
                    if (q_value_reg <1) q_value_reg =1;
                    state <= INSERT;
                end else if (q_type_reg ==2) begin
                    if (q_value_reg >0 && q_value_reg <= n) begin
                        result <= movies[q_value_reg -1];
                    end else begin
                        result <=0;
                    end
                    state <= DONE_STATE;
                end else begin
                    state <= DONE_STATE;
                    result <=0;
                end
            end
            INSERT: begin
                if (n >= MAX_MOVIES) begin
                    state <= DONE_STATE;
                    result <=0;
                end else begin
                    if (q_value_reg > n) begin
                        movies[n] <= next_idx_reg;
                        n <= n +1;
                        state <= DONE_STATE;
                        result <=1;
                    end else begin
                        target_reg <= q_value_reg -1;
                        shift_count <= n - target_reg;
                        shift_index <= n -1;
                        state <= SHIFT;
                    end
                end
            end
            SHIFT: begin
                if (shift_count >0) begin
                    movies[shift_index +1] <= movies[shift_index];
                    shift_index <= shift_index -1;
                    shift_count <= shift_count -1;
                end else begin
                    movies[target_reg] <= next_idx_reg;
                    n <= n +1;
                    state <= DONE_STATE;
                    result <=1;
                end
            end
            DONE_STATE: begin
            end
            default: state <= IDLE;
        endcase
    end
endmodule