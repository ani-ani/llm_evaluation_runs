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

    // State definitions
    localparam [2:0] IDLE          = 3'b000;
    localparam [2:0] INIT_RATINGS  = 3'b001;
    localparam [2:0] FIND_MAX      = 3'b010;
    localparam [2:0] FORM_PARTY    = 3'b011;
    localparam [2:0] UPDATE_RATINGS= 3'b100;
    localparam [2:0] OUTPUT_MATCH  = 3'b101;
    localparam [2:0] CHECK_DONE    = 3'b110;
    localparam [2:0] FINISHED      = 3'b111;

    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [3:0] current_ratings [0:7];
    reg [13:0] match_counter;
    reg [2:0] max_idx;
    reg [2:0] party_size;
    reg [2:0] party [0:4];
    reg [2:0] step_counter;
    reg [2:0] i, j;  // Loop counters
    reg all_equal;
    reg [7:0] match_temp [0:7];

    // Combinational logic for finding maximum
    reg [3:0] max_rating;
    always @(*) begin
        max_rating = 4'd0;
        max_idx = 3'd0;
        for (i = 0; i < 8; i = i + 1) begin
            if (i < n) begin
                if (current_ratings[i] > max_rating) begin
                    max_rating = current_ratings[i];
                    max_idx = i;
                end
            end
        end
    end

    // Combinational logic for checking if all ratings equal
    always @(*) begin
        all_equal = 1'b1;
        for (i = 1; i < 8; i = i + 1) begin
            if (i < n) begin
                if (current_ratings[i] != current_ratings[0]) begin
                    all_equal = 1'b0;
                end
            end
        end
    end

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            final_rating <= 4'd0;
            match_count <= 14'd0;
            match_valid <= 1'b0;
            done <= 1'b0;
            match_counter <= 14'd0;
            step_counter <= 3'd0;
            party_size <= 3'd0;
            for (j = 0; j < 8; j = j + 1) begin
                current_ratings[j] <= 4'd0;
                match_temp[j] <= 8'd0;
            end
            for (j = 0; j < 5; j = j + 1) begin
                party[j] <= 3'd0;
            end
            match_0 <= 8'd0; match_1 <= 8'd0; match_2 <= 8'd0; match_3 <= 8'd0;
            match_4 <= 8'd0; match_5 <= 8'd0; match_6 <= 8'd0; match_7 <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    match_valid <= 1'b0;
                    match_counter <= 14'd0;
                    step_counter <= 3'd0;
                    if (start) begin
                        // Initialize ratings
                        current_ratings[0] <= ratings_0;
                        current_ratings[1] <= ratings_1;
                        current_ratings[2] <= ratings_2;
                        current_ratings[3] <= ratings_3;
                        current_ratings[4] <= ratings_4;
                        current_ratings[5] <= ratings_5;
                        current_ratings[6] <= ratings_6;
                        current_ratings[7] <= ratings_7;
                    end
                end

                FIND_MAX: begin
                    // Max found by combinational logic
                end

                FORM_PARTY: begin
                    // Form party based on max rating count
                    if (max_rating == 0) begin
                        party_size <= 3'd0;
                    end else begin
                        reg [2:0] count_max;
                        count_max = 3'd0;
                        // Count how many have max rating
                        for (i = 0; i < 8; i = i + 1) begin
                            if (i < n && current_ratings[i] == max_rating) begin
                                count_max = count_max + 1;
                            end
                        end
                        
                        if (count_max >= 2 && count_max <= 5) begin
                            // Take all friends with max rating
                            party_size <= 3'd0;
                            for (i = 0; i < 8; i = i + 1) begin
                                if (i < n && current_ratings[i] == max_rating && party_size < 5) begin
                                    party[party_size] <= i;
                                    party_size <= party_size + 1;
                                end
                            end
                        end else begin
                            // Take two highest rated friends
                            reg [2:0] first_max, second_max;
                            first_max = 3'd0;
                            second_max = 3'd1;
                            // Find first maximum
                            for (i = 1; i < 8; i = i + 1) begin
                                if (i < n && current_ratings[i] > current_ratings[first_max]) begin
                                    first_max = i;
                                end
                            end
                            // Find second maximum
                            for (i = 0; i < 8; i = i + 1) begin
                                if (i < n && i != first_max) begin
                                    if (i < n && current_ratings[i] > current_ratings[second_max]) begin
                                        second_max = i;
                                    end
                                end
                            end
                            party[0] <= first_max;
                            party[1] <= second_max;
                            party_size <= 3'd2;
                        end
                    end
                end

                UPDATE_RATINGS: begin
                    // Update ratings for selected friends
                    for (i = 0; i < 5; i = i + 1) begin
                        if (i < party_size) begin
                            reg [2:0] friend_idx;
                            friend_idx = party[i];
                            if (current_ratings[friend_idx] > 0) begin
                                current_ratings[friend_idx] <= current_ratings[friend_idx] - 1;
                            end
                        end
                    end
                end

                OUTPUT_MATCH: begin
                    // Output the current match
                    match_valid <= 1'b1;
                    match_temp[0] <= 8'd0;
                    match_temp[1] <= 8'd0;
                    match_temp[2] <= 8'd0;
                    match_temp[3] <= 8'd0;
                    match_temp[4] <= 8'd0;
                    match_temp[5] <= 8'd0;
                    match_temp[6] <= 8'd0;
                    match_temp[7] <= 8'd0;
                    
                    for (i = 0; i < 5; i = i + 1) begin
                        if (i < party_size) begin
                            reg [2:0] idx;
                            idx = party[i];
                            if (idx == 0) match_temp[0] <= 8'd1;
                            else if (idx == 1) match_temp[1] <= 8'd1;
                            else if (idx == 2) match_temp[2] <= 8'd1;
                            else if (idx == 3) match_temp[3] <= 8'd1;
                            else if (idx == 4) match_temp[4] <= 8'd1;
                            else if (idx == 5) match_temp[5] <= 8'd1;
                            else if (idx == 6) match_temp[6] <= 8'd1;
                            else if (idx == 7) match_temp[7] <= 8'd1;
                        end
                    end
                    
                    match_0 <= match_temp[0];
                    match_1 <= match_temp[1];
                    match_2 <= match_temp[2];
                    match_3 <= match_temp[3];
                    match_4 <= match_temp[4];
                    match_5 <= match_temp[5];
                    match_6 <= match_temp[6];
                    match_7 <= match_temp[7];
                    match_counter <= match_counter + 1;
                end

                CHECK_DONE: begin
                    match_valid <= 1'b0;
                    if (all_equal) begin
                        final_rating <= current_ratings[0];
                        match_count <= match_counter;
                    end else if (step_counter >= 15) begin
                        final_rating <= current_ratings[0];
                        match_count <= match_counter;
                    end else begin
                        step_counter <= step_counter + 1;
                    end
                end

                FINISHED: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = FIND_MAX;
                end
            end

            FIND_MAX: begin
                next_state = FORM_PARTY;
            end

            FORM_PARTY: begin
                if (max_rating == 0) begin
                    next_state = FINISHED;
                end else begin
                    next_state = UPDATE_RATINGS;
                end
            end

            UPDATE_RATINGS: begin
                next_state = OUTPUT_MATCH;
            end

            OUTPUT_MATCH: begin
                next_state = CHECK_DONE;
            end

            CHECK_DONE: begin
                if (all_equal || step_counter >= 15) begin
                    next_state = FINISHED;
                end else begin
                    next_state = FIND_MAX;
                end
            end

            FINISHED: begin
                if (!start) begin
                    next_state = IDLE;
                end
            end

            default: next_state = IDLE;
        endcase
    end

endmodule