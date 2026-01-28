module rating_equalizer(
    input clk,
    input rst_n,
    input start,
    input [7:0] rating [0:9],
    input [3:0] n,
    output reg [7:0] result,
    output reg [15:0] match_count,
    output reg [9:0] match_out,
    output reg match_valid,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] LOAD = 2'd1;
    localparam [1:0] FIND_MAX = 2'd2;
    localparam [1:0] PROCESS = 2'd3;
    localparam [1:0] OUTPUT = 2'd4;
    localparam [1:0] DONE_STATE = 2'd5;

    reg [1:0] state, next_state;
    reg [7:0] current_ratings [0:9];
    reg [7:0] max_val, second_max;
    reg [3:0] max_index, second_max_index;
    reg [3:0] match_size;
    reg [9:0] match_pattern;
    reg [7:0] cycle_count;
    reg [3:0] i, j;
    reg all_equal;
    reg [3:0] count_max;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            match_count <= 16'd0;
            match_out <= 10'd0;
            match_valid <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            i <= 4'd0;
            j <= 4'd0;
            all_equal <= 1'b1;
            count_max <= 4'd0;
            for (j = 0; j < 10; j = j + 1) begin
                current_ratings[j] <= 8'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        match_valid = 1'b0;
        done = 1'b0;
        all_equal = 1'b1;
        max_val = 8'd0;
        second_max = 8'd0;
        max_index = 4'd0;
        second_max_index = 4'd0;
        count_max = 4'd0;
        match_pattern = 10'd0;
        match_size = 4'd0;

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD;
                end
            end

            LOAD: begin
                for (i = 0; i < 10; i = i + 1) begin
                    if (i < n) begin
                        current_ratings[i] = rating[i];
                    end else begin
                        current_ratings[i] = 8'd0;
                    end
                end
                next_state = FIND_MAX;
            end

            FIND_MAX: begin
                // Find max and second max values
                for (i = 0; i < n; i = i + 1) begin
                    if (current_ratings[i] > max_val) begin
                        second_max = max_val;
                        second_max_index = max_index;
                        max_val = current_ratings[i];
                        max_index = i;
                        count_max = 4'd1;
                    end else if (current_ratings[i] == max_val) begin
                        count_max = count_max + 4'd1;
                    end else if (current_ratings[i] > second_max) begin
                        second_max = current_ratings[i];
                        second_max_index = i;
                    end
                end

                // Check if all equal
                all_equal = 1'b1;
                for (i = 0; i < n; i = i + 1) begin
                    if (current_ratings[i] != max_val) begin
                        all_equal = 1'b0;
                    end
                end

                if (all_equal) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = PROCESS;
                end
            end

            PROCESS: begin
                // Determine match size and pattern
                if (count_max >= 3) begin
                    match_size = 4'd3;
                    match_pattern = 10'd0;
                    for (i = 0; i < n; i = i + 1) begin
                        if (current_ratings[i] == max_val) begin
                            match_pattern[i] = 1'b1;
                        end
                    end
                end else begin
                    match_size = 4'd2;
                    match_pattern = 10'd0;
                    match_pattern[max_index] = 1'b1;
                    match_pattern[second_max_index] = 1'b1;
                end
                next_state = OUTPUT;
            end

            OUTPUT: begin
                match_out = match_pattern;
                match_valid = 1'b1;
                match_count = match_count + 16'd1;

                // Decrement ratings
                for (i = 0; i < n; i = i + 1) begin
                    if (match_pattern[i]) begin
                        if (current_ratings[i] > 8'd0) begin
                            current_ratings[i] = current_ratings[i] - 8'd1;
                        end
                    end
                end

                next_state = FIND_MAX;
            end

            DONE_STATE: begin
                result = max_val;
                done = 1'b1;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule