module rating_equalizer (
    input clk,
    input rst_n,
    input start,
    input [3:0] ratings_0, ratings_1, ratings_2, ratings_3,
    input [3:0] ratings_4, ratings_5, ratings_6, ratings_7,
    input [3:0] n,
    output reg [3:0] final_rating,
    output reg [13:0] match_count,
    output reg [7:0] match_0, match_1, match_2, match_3,
    output reg [7:0] match_4, match_5, match_6, match_7,
    output reg match_valid,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] COMPUTE_MAX = 3'd1;
    localparam [2:0] FORM_PARTY  = 3'd2;
    localparam [2:0] UPDATE_RATE = 3'd3;
    localparam [2:0] OUT_MATCH   = 3'd4;
    localparam [2:0] CHECK_EQUAL = 3'd5;
    localparam [2:0] FINISHED    = 3'd6;

    reg [2:0] state, next_state;
    reg [3:0] current_ratings [0:7];
    reg [3:0] step_count;
    reg [3:0] max_rating;
    reg [2:0] max_count;
    reg [2:0] selected_friends [0:4];
    reg [2:0] selected_cnt;
    reg [1:0] first_max, second_max;
    reg [3:0] i;  // Loop index

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize registers
            state <= IDLE;
            final_rating <= 4'd0;
            match_count <= 14'd0;
            match_valid <= 1'b0;
            done <= 1'b0;
            step_count <= 4'd0;
            max_rating <= 4'd0;
            max_count <= 3'd0;
            selected_cnt <= 3'd0;
            first_max <= 2'd0;
            second_max <= 2'd0;

            // Initialize arrays
            for (i = 0; i < 8; i = i + 1) begin
                current_ratings[i] <= 4'd0;
                if (i < 5) selected_friends[i] <= 3'd0;
            end

            // Initialize match outputs
            match_0 <= 8'd0;
            match_1 <= 8'd0;
            match_2 <= 8'd0;
            match_3 <= 8'd0;
            match_4 <= 8'd0;
            match_5 <= 8'd0;
            match_6 <= 8'd0;
            match_7 <= 8'd0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Load input ratings
                        current_ratings[0] <= ratings_0;
                        current_ratings[1] <= ratings_1;
                        current_ratings[2] <= ratings_2;
                        current_ratings[3] <= ratings_3;
                        current_ratings[4] <= ratings_4;
                        current_ratings[5] <= ratings_5;
                        current_ratings[6] <= ratings_6;
                        current_ratings[7] <= ratings_7;
                        match_count <= 14'd0;
                        step_count <= 4'd0;
                        next_state <= COMPUTE_MAX;
                    end
                end

                COMPUTE_MAX: begin
                    max_rating <= 4'd0;
                    max_count <= 3'd0;
                    for (i = 0; i < 8; i = i + 1) begin
                        if (i < n) begin
                            if (current_ratings[i] > max_rating) begin
                                max_rating <= current_ratings[i];
                                max_count <= 3'd1;
                            end
                            else if (current_ratings[i] == max_rating) begin
                                max_count <= max_count + 3'd1;
                            end
                        end
                    end
                    next_state <= FORM_PARTY;
                end

                FORM_PARTY: begin
                    selected_cnt <= 3'd0;
                    if ((max_count >= 3'd2) && (max_count <= 3'd5)) begin
                        // Select all max-rated friends
                        for (i = 0; i < 8; i = i + 1) begin
                            if ((i < n) && (current_ratings[i] == max_rating) && (selected_cnt < 3'd5)) begin
                                selected_friends[selected_cnt] <= i;
                                selected_cnt <= selected_cnt + 3'd1;
                            end
                        end
                    end else begin
                        // Find first and second max
                        first_max <= 2'd0;
                        second_max <= 2'd0;
                        for (i = 1; i < 8; i = i + 1) begin
                            if (i < n) begin
                                if (current_ratings[i] > current_ratings[first_max]) begin
                                    first_max <= i;
                                end
                            end
                        end
                        for (i = 0; i < 8; i = i + 1) begin
                            if ((i < n) && (i != first_max)) begin
                                if ((second_max == first_max) || (current_ratings[i] > current_ratings[second_max])) begin
                                    second_max <= i;
                                end
                            end
                        end
                        selected_friends[0] <= first_max;
                        selected_friends[1] <= second_max;
                        selected_cnt <= 3'd2;
                    end
                    next_state <= UPDATE_RATE;
                end

                UPDATE_RATE: begin
                    // Decrement selected ratings
                    for (i = 0; i < 5; i = i + 1) begin
                        if (i < selected_cnt) begin
                            if (current_ratings[selected_friends[i]] > 4'd0) begin
                                current_ratings[selected_friends[i]] <= current_ratings[selected_friends[i]] - 4'd1;
                            end
                        end
                    end
                    next_state <= OUT_MATCH;
                end

                OUT_MATCH: begin
                    match_valid <= 1'b1;
                    match_count <= match_count + 14'd1;

                    // Update match indicators
                    match_0 <= (selected_friends[0] == 3'd0) ? (match_0 | (8'd1 << step_count)) : match_0;
                    match_1 <= (selected_friends[0] == 3'd1) ? (match_1 | (8'd1 << step_count)) : match_1;
                    match_2 <= (selected_friends[0] == 3'd2) ? (match_2 | (8'd1 << step_count)) : match_2;
                    match_3 <= (selected_friends[0] == 3'd3) ? (match_3 | (8'd1 << step_count)) : match_3;
                    match_4 <= (selected_friends[0] == 3'd4) ? (match_4 | (8'd1 << step_count)) : match_4;
                    match_5 <= (selected_friends[0] == 3'd5) ? (match_5 | (8'd1 << step_count)) : match_5;
                    match_6 <= (selected_friends[0] == 3'd6) ? (match_6 | (8'd1 << step_count)) : match_6;
                    match_7 <= (selected_friends[0] == 3'd7) ? (match_7 | (8'd1 << step_count)) : match_7;

                    // Handle additional selected friends
                    if (selected_cnt > 3'd1) begin
                        match_0 <= (selected_friends[1] == 3'd0) ? (match_0 | (8'd1 << step_count)) : match_0;
                        match_1 <= (selected_friends[1] == 3'd1) ? (match_1 | (8'd1 << step_count)) : match_1;
                        match_2 <= (selected_friends[1] == 3'd2) ? (match_2 | (8'd1 << step_count)) : match_2;
                        match_3 <= (selected_friends[1] == 3'd3) ? (match_3 | (8'd1 << step_count)) : match_3;
                        match_4 <= (selected_friends[1] == 3'd4) ? (match_4 | (8'd1 << step_count)) : match_4;
                        match_5 <= (selected_friends[1] == 3'd5) ? (match_5 | (8'd1 << step_count)) : match_5;
                        match_6 <= (selected_friends[1] == 3'd6) ? (match_6 | (8'd1 << step_count)) : match_6;
                        match_7 <= (selected_friends[1] == 3'd7) ? (match_7 | (8'd1 << step_count)) : match_7;
                    end
                    next_state <= CHECK_EQUAL;
                end

                CHECK_EQUAL: begin
                    match_valid <= 1'b0;
                    step_count <= step_count + 4'd1;

                    // Check all equal or max steps
                    reg all_equal;
                    all_equal = 1'b1;
                    for (i = 1; i < 8; i = i + 1) begin
                        if (i < n && current_ratings[i] != current_ratings[0]) begin
                            all_equal = 1'b0;
                        end
                    end

                    if (all_equal || (step_count >= 4'd15)) begin
                        final_rating <= current_ratings[0];
                        next_state <= FINISHED;
                    end else begin
                        next_state <= COMPUTE_MAX;
                    end
                end

                FINISHED: begin
                    done <= 1'b1;
                    if (!start) begin
                        next_state <= IDLE;
                    end
                end

                default: next_state <= IDLE;
            endcase
        end
    end
endmodule