module lifeguard_divider (
    input clk,
    input rst_n,
    input start,
    input [7:0] num_swimmers,
    input [31:0] swimmer_x [0:7],
    input [31:0] swimmer_y [0:7],
    output reg [31:0] lifeguard1_x,
    output reg [31:0] lifeguard1_y,
    output reg [31:0] lifeguard2_x,
    output reg [31:0] lifeguard2_y,
    output reg done,
    output reg valid
);

    // State definitions
    typedef enum logic [1:0] {
        IDLE,
        SEARCH,
        VERIFY,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Candidate position counters
    reg [11:0] lg1_x_counter;
    reg [11:0] lg1_y_counter;
    reg [11:0] lg2_x_counter;
    reg [11:0] lg2_y_counter;

    // Verification counters
    reg [3:0] swimmer_index;
    reg [3:0] count1;
    reg [3:0] count2;
    reg equidistant_count;

    // Temporary storage for candidate positions
    reg [31:0] temp_lg1_x;
    reg [31:0] temp_lg1_y;
    reg [31:0] temp_lg2_x;
    reg [31:0] temp_lg2_y;

    // Distance calculation variables
    reg [31:0] dist1;
    reg [31:0] dist2;
    reg [31:0] dx1, dy1, dx2, dy2;

    // Control signals
    reg solution_found;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            done <= 0;
            valid <= 0;
            solution_found <= 0;
            lg1_x_counter <= 0;
            lg1_y_counter <= 0;
            lg2_x_counter <= 0;
            lg2_y_counter <= 0;
            swimmer_index <= 0;
            count1 <= 0;
            count2 <= 0;
            equidistant_count <= 0;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = SEARCH;
                    done = 0;
                    valid = 0;
                    solution_found = 0;
                    lg1_x_counter = 0;
                    lg1_y_counter = 0;
                    lg2_x_counter = 0;
                    lg2_y_counter = 0;
                end
            end
            SEARCH: begin
                if (lg1_x_counter == 21 && lg1_y_counter == 21 && lg2_x_counter == 21 && lg2_y_counter == 21) begin
                    next_state = DONE;
                end else begin
                    next_state = VERIFY;
                    temp_lg1_x = $signed(100 * lg1_x_counter - 1000);
                    temp_lg1_y = $signed(100 * lg1_y_counter - 1000);
                    temp_lg2_x = $signed(100 * lg2_x_counter - 1000);
                    temp_lg2_y = $signed(100 * lg2_y_counter - 1000);
                    swimmer_index = 0;
                    count1 = 0;
                    count2 = 0;
                    equidistant_count = 0;
                end
            end
            VERIFY: begin
                if (swimmer_index == num_swimmers) begin
                    if ((equidistant_count <= 1) && 
                        ((count1 == count2) || 
                         (count1 + 1 == count2 && equidistant_count == 1) ||
                         (count2 + 1 == count1 && equidistant_count == 1))) begin
                        solution_found = 1;
                        lifeguard1_x = temp_lg1_x;
                        lifeguard1_y = temp_lg1_y;
                        lifeguard2_x = temp_lg2_x;
                        lifeguard2_y = temp_lg2_y;
                        next_state = DONE;
                    end else begin
                        next_state = SEARCH;
                        // Increment counters for next candidate
                        if (lg2_y_counter == 21) begin
                            if (lg2_x_counter == 21) begin
                                if (lg1_y_counter == 21) begin
                                    if (lg1_x_counter == 21) begin
                                        next_state = DONE;
                                    end else begin
                                        lg1_x_counter = lg1_x_counter + 1;
                                        lg1_y_counter = 0;
                                        lg2_x_counter = 0;
                                        lg2_y_counter = 0;
                                    end
                                end else begin
                                    lg1_y_counter = lg1_y_counter + 1;
                                    lg2_x_counter = 0;
                                    lg2_y_counter = 0;
                                end
                            end else begin
                                lg2_x_counter = lg2_x_counter + 1;
                                lg2_y_counter = 0;
                            end
                        end else begin
                            lg2_y_counter = lg2_y_counter + 1;
                        end
                    end
                end
            end
            DONE: begin
                done = 1;
                valid = solution_found;
            end
        endcase
    end

    // Verification logic
    always @(posedge clk) begin
        if (current_state == VERIFY && swimmer_index < num_swimmers) begin
            dx1 = swimmer_x[swimmer_index] - temp_lg1_x;
            dy1 = swimmer_y[swimmer_index] - temp_lg1_y;
            dx2 = swimmer_x[swimmer_index] - temp_lg2_x;
            dy2 = swimmer_y[swimmer_index] - temp_lg2_y;
            
            dist1 = dx1 * dx1 + dy1 * dy1;
            dist2 = dx2 * dx2 + dy2 * dy2;
            
            if (dist1 < dist2) begin
                count1 = count1 + 1;
            end else if (dist2 < dist1) begin
                count2 = count2 + 1;
            end else begin
                equidistant_count = 1;
            end
            
            swimmer_index = swimmer_index + 1;
        end
    end

endmodule