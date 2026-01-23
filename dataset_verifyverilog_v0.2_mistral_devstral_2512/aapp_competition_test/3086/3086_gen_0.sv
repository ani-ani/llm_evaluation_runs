module event_duration_solver (
    input clk,
    input rst_n,
    input start,
    input [8:0] start_day,
    input [8:0] end_day,
    input [7:0] F [0:3],
    output reg [8:0] duration [0:3],
    output reg done,
    output reg valid
);

    // Parameters
    localparam IDLE = 3'b000;
    localparam READ_OBS = 3'b001;
    localparam SOLVE = 3'b010;
    localparam CHECK = 3'b011;
    localparam OUTPUT = 3'b100;

    // State register
    reg [2:0] state, next_state;

    // Internal registers
    reg [8:0] observation_window;
    reg [8:0] d0, d1, d2, d3;
    reg [8:0] d0_counter, d1_counter, d2_counter, d3_counter;
    reg [8:0] sum;
    reg [3:0] obs_index;
    reg [3:0] check_index;
    reg [8:0] current_sum;
    reg solution_found;

    // Calculate observation window
    always @(*) begin
        if (end_day >= start_day) begin
            observation_window = end_day - start_day;
        end else begin
            observation_window = end_day + 365 - start_day;
        end
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
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
                    next_state = READ_OBS;
                end
            end
            READ_OBS: begin
                next_state = SOLVE;
            end
            SOLVE: begin
                if (d0_counter == 365 && d1_counter == 365 && d2_counter == 365 && d3_counter == 365) begin
                    next_state = OUTPUT;
                end else if (d0_counter < 365) begin
                    next_state = CHECK;
                end
            end
            CHECK: begin
                if (check_index == 3) begin
                    next_state = SOLVE;
                end
            end
            OUTPUT: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            observation_window <= 0;
            d0 <= 0; d1 <= 0; d2 <= 0; d3 <= 0;
            d0_counter <= 0; d1_counter <= 0; d2_counter <= 0; d3_counter <= 0;
            sum <= 0;
            obs_index <= 0;
            check_index <= 0;
            current_sum <= 0;
            solution_found <= 0;
            done <= 0;
            valid <= 0;
            duration[0] <= 0; duration[1] <= 0; duration[2] <= 0; duration[3] <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    valid <= 0;
                end
                READ_OBS: begin
                    // Load observation data (simplified for single observation)
                    d0_counter <= 1;
                    d1_counter <= 1;
                    d2_counter <= 1;
                    d3_counter <= 1;
                    solution_found <= 0;
                end
                SOLVE: begin
                    // Increment counters for duration search
                    if (d3_counter == 365) begin
                        d3_counter <= 1;
                        if (d2_counter == 365) begin
                            d2_counter <= 1;
                            if (d1_counter == 365) begin
                                d1_counter <= 1;
                                d0_counter <= d0_counter + 1;
                            end else begin
                                d1_counter <= d1_counter + 1;
                            end
                        end else begin
                            d2_counter <= d2_counter + 1;
                        end
                    end else begin
                        d3_counter <= d3_counter + 1;
                    end
                    
                    // Set current duration values
                    d0 <= d0_counter;
                    d1 <= d1_counter;
                    d2 <= d2_counter;
                    d3 <= d3_counter;
                    
                    // Reset check index
                    check_index <= 0;
                    current_sum <= 0;
                end
                CHECK: begin
                    // Calculate partial sum
                    case (check_index)
                        0: current_sum <= F[0] * d0;
                        1: current_sum <= current_sum + F[1] * d1;
                        2: current_sum <= current_sum + F[2] * d2;
                        3: current_sum <= current_sum + F[3] * d3;
                    endcase
                    
                    // Check if sum matches observation window
                    if (check_index == 3 && current_sum == observation_window) begin
                        solution_found <= 1;
                        duration[0] <= d0;
                        duration[1] <= d1;
                        duration[2] <= d2;
                        duration[3] <= d3;
                    end
                    
                    check_index <= check_index + 1;
                end
                OUTPUT: begin
                    done <= 1;
                    valid <= solution_found;
                end
            endcase
        end
    end

endmodule