module train_sorter (
    input clk,
    input rst_n,
    input start,
    input [15:0] p_in,
    input [3:0] idx_in,
    output reg [3:0] result,
    output reg done
);

    // Parameters
    localparam N = 16;
    localparam IDLE = 2'b00;
    localparam LOAD = 2'b01;
    localparam COMPUTE = 2'b10;
    localparam DONE = 2'b11;

    // State register
    reg [1:0] state, next_state;

    // Position storage (pos[value-1] = position)
    reg [3:0] pos [0:N-1];

    // Load counter
    reg [3:0] load_cnt;

    // Compute variables
    reg [3:0] max_len, curr_len;
    reg [3:0] i, j;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            load_cnt <= 0;
            max_len <= 0;
            curr_len <= 0;
            i <= 0;
            j <= 0;
            done <= 0;
            result <= 0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = LOAD;
            end
            LOAD: begin
                if (load_cnt == N-1) next_state = COMPUTE;
            end
            COMPUTE: begin
                if (i == N-1) next_state = DONE;
            end
            DONE: begin
                if (!start) next_state = IDLE;
            end
        endcase
    end

    // Load data
    always @(posedge clk) begin
        if (state == LOAD && load_cnt < N) begin
            pos[p_in-1] <= idx_in;
            load_cnt <= load_cnt + 1;
        end
    end

    // Compute longest increasing subsequence
    always @(posedge clk) begin
        if (state == COMPUTE) begin
            if (i == 0) begin
                curr_len <= 1;
                max_len <= 1;
                j <= 0;
            end else if (j == i) begin
                if (curr_len > max_len) max_len <= curr_len;
                curr_len <= 1;
                j <= 0;
            end else begin
                if (pos[j] < pos[i] && j == i-1) begin
                    curr_len <= curr_len + 1;
                end
                j <= j + 1;
            end
            i <= (j == i) ? i + 1 : i;
        end
    end

    // Output result
    always @(posedge clk) begin
        if (state == DONE) begin
            result <= N - max_len;
            done <= 1;
        end else if (state != IDLE) begin
            done <= 0;
        end
    end

endmodule