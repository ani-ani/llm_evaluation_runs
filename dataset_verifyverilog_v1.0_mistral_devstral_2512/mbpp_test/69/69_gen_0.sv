module sublist_checker(
    input clk,
    input rst_n,
    input start,
    input [2:0] main_len,
    input [2:0] sub_len,
    input [7:0] main_arr [0:7],
    input [7:0] sub_arr [0:7],
    output reg result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] COMPARE   = 3'd1;
    localparam [2:0] FINISH    = 3'd2;

    reg [2:0] state, next_state;
    reg [2:0] main_index;      // Current position in main_arr
    reg [2:0] sub_index;       // Current position in sub_arr
    reg [2:0] match_count;     // Count of consecutive matches
    reg [7:0] cycle_count;     // Prevent infinite loops
    localparam [7:0] MAX_CYCLES = 8'd100;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            main_index <= 3'd0;
            sub_index <= 3'd0;
            match_count <= 3'd0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = COMPARE;
                end
            end

            COMPARE: begin
                // Check if we've found a complete match
                if (match_count == sub_len) begin
                    next_state = FINISH;
                end
                // Check if we've exhausted all possible positions
                else if (main_index + sub_len > main_len) begin
                    next_state = FINISH;
                end
                // Check if current elements match
                else if (main_arr[main_index] == sub_arr[sub_index]) begin
                    // Continue matching
                    next_state = COMPARE;
                end
                else begin
                    // Reset for next position
                    next_state = COMPARE;
                end
            end

            FINISH: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            main_index <= 3'd0;
            sub_index <= 3'd0;
            match_count <= 3'd0;
            cycle_count <= 8'd0;
            result <= 1'b0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 1'b0;
                    main_index <= 3'd0;
                    sub_index <= 3'd0;
                    match_count <= 3'd0;
                    cycle_count <= 8'd0;
                end

                COMPARE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if we have a complete match
                    if (match_count == sub_len) begin
                        result <= 1'b1;
                    end
                    // Check if we've exhausted all positions
                    else if (main_index + sub_len > main_len) begin
                        result <= 1'b0;
                    end
                    // Check current elements
                    else if (main_arr[main_index] == sub_arr[sub_index]) begin
                        // Increment both indices and match count
                        if (sub_index == sub_len - 1) begin
                            main_index <= main_index + 3'd1;
                            sub_index <= 3'd0;
                            match_count <= match_count + 3'd1;
                        end else begin
                            sub_index <= sub_index + 3'd1;
                        end
                    end else begin
                        // No match, move to next position
                        main_index <= main_index + 3'd1;
                        sub_index <= 3'd0;
                        match_count <= 3'd0;
                    end
                    
                    // Safety: prevent infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        result <= 1'b0;
                        next_state = FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                end

                default: begin
                    main_index <= 3'd0;
                    sub_index <= 3'd0;
                    match_count <= 3'd0;
                    cycle_count <= 8'd0;
                    result <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end
endmodule