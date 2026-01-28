module queue_elimination(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] values_in [0:15],
    input wire [3:0] len_in,
    output reg [15:0] result_final [0:15],
    output reg [3:0] len_final,
    output reg [15:0] result_rounds [0:15][0:15],
    output reg [3:0] round_counts [0:15],
    output reg [3:0] num_rounds,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] CHECK = 3'd2;
    localparam [2:0] REMOVE = 3'd3;
    localparam [2:0] STORE = 3'd4;
    localparam [2:0] FINISH = 3'd5;

    reg [2:0] state, next_state;

    // Queue and control registers
    reg [15:0] queue [0:15];
    reg [3:0] current_len;
    reg [3:0] round_idx;
    reg [3:0] removal_count;
    reg [3:0] cycle_count;
    reg [15:0] to_remove [0:15];
    reg [3:0] temp_len;
    reg [15:0] temp_queue [0:15];

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            current_len <= 4'd0;
            round_idx <= 4'd0;
            removal_count <= 4'd0;
            cycle_count <= 4'd0;
            num_rounds <= 4'd0;
            done <= 1'b0;

            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                queue[i] <= 16'd0;
                to_remove[i] <= 16'd0;
                temp_queue[i] <= 16'd0;
                integer j;
                for (j = 0; j < 16; j = j + 1) begin
                    result_rounds[i][j] <= 16'd0;
                end
                round_counts[i] <= 4'd0;
            end
            len_final <= 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                result_final[i] <= 16'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // State machine logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INIT;
                end
            end

            INIT: begin
                next_state = CHECK;
            end

            CHECK: begin
                next_state = REMOVE;
            end

            REMOVE: begin
                if (removal_count == 4'd0) begin
                    next_state = FINISH;
                end else begin
                    next_state = STORE;
                end
            end

            STORE: begin
                next_state = CHECK;
            end

            FINISH: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Initialize queue on start
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already handled in reset
        end else if (state == INIT) begin
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                if (i < len_in) begin
                    queue[i] <= values_in[i];
                end else begin
                    queue[i] <= 16'd0;
                end
            end
            current_len <= len_in;
            round_idx <= 4'd0;
            removal_count <= 4'd0;
            cycle_count <= 4'd0;
            num_rounds <= 4'd0;
        end
    end

    // Check for removals
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already handled in reset
        end else if (state == CHECK) begin
            integer i;
            removal_count <= 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                to_remove[i] <= 16'd0;
            end

            for (i = 0; i < current_len - 1; i = i + 1) begin
                if (queue[i] < queue[i + 1]) begin
                    to_remove[i] <= 16'd1;
                    removal_count <= removal_count + 4'd1;
                end
                if (queue[i + 1] < queue[i]) begin
                    to_remove[i + 1] <= 16'd1;
                    removal_count <= removal_count + 4'd1;
                end
            end
        end
    end

    // Remove marked candidates
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already handled in reset
        end else if (state == REMOVE) begin
            temp_len <= 4'd0;
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                temp_queue[i] <= 16'd0;
            end

            for (i = 0; i < current_len; i = i + 1) begin
                if (to_remove[i] == 16'd0) begin
                    temp_queue[temp_len] <= queue[i];
                    temp_len <= temp_len + 4'd1;
                end
            end

            current_len <= temp_len;
            for (i = 0; i < 16; i = i + 1) begin
                queue[i] <= temp_queue[i];
            end
        end
    end

    // Store round results
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already handled in reset
        end else if (state == STORE) begin
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                result_rounds[round_idx][i] <= queue[i];
            end
            round_counts[round_idx] <= removal_count;
            round_idx <= round_idx + 4'd1;
            num_rounds <= num_rounds + 4'd1;
            cycle_count <= cycle_count + 4'd1;
        end
    end

    // Finalize results
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already handled in reset
        end else if (state == FINISH) begin
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                result_final[i] <= queue[i];
            end
            len_final <= current_len;
            done <= 1'b1;
        end else begin
            done <= 1'b0;
        end
    end

    // Safety counter to prevent infinite loops
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 4'd0;
        end else if (state != IDLE && state != FINISH) begin
            if (cycle_count >= 4'd255) begin
                next_state = FINISH;
            end
        end
    end

endmodule