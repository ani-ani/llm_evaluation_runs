module sign_distance_average(
    input clk,
    input rst_n,
    input start,
    input [1:0] n,
    input [15:0] dist_matrix [5:0],
    output reg [31:0] avg_distance,
    output reg done,
    output reg impossible
);

typedef enum {IDLE, LOAD, CALC, DONE} state_t;
state_t current_state, next_state;

reg [15:0] num_pairs;
reg [18:0] sum;
reg [18:0] quotient;
reg [2:0] remainder;
reg [15:0] fractional;
reg [1:0] saved_n;

// State machine
always_ff @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        current_state <= IDLE;
    end else begin
        current_state <= next_state;
    end
end

// Next state logic
always_comb begin
    next_state = current_state;
    case (current_state)
        IDLE: if (start) next_state = LOAD;
        LOAD: next_state = CALC;
        CALC: next_state = DONE;
        DONE: if (~start) next_state = IDLE;
    endcase
end

// Sum calculation and division
always_ff @(posedge clk) begin
    if (~rst_n) begin
        sum <= 0;
        done <= 0;
        impossible <= 0;
        saved_n <= 0;
    end else begin
        case (current_state)
            IDLE: begin
                done <= 0;
                impossible <= 0;
                saved_n <= n;
                
                if (start) begin
                    case (n)
                        2: num_pairs <= 1;
                        3: num_pairs <= 3;
                        4: num_pairs <= 6;
                        default: num_pairs <= 0;
                    endcase
                end
            end
            
            LOAD: begin
                sum <= 0;
                case (saved_n)
                    2: sum <= dist_matrix[0];
                    3: sum <= dist_matrix[0] + dist_matrix[1] + dist_matrix[2];
                    4: sum <= dist_matrix[0] + dist_matrix[1] + dist_matrix[2] + dist_matrix[3] + dist_matrix[4] + dist_matrix[5];
                endcase
            end
            
            CALC: begin
                quotient <= sum / num_pairs;
                remainder <= sum % num_pairs;
                
                // Fractional part lookup
                case (num_pairs)
                    1: fractional <= 0;
                    3: begin
                        case (remainder)
                            0: fractional <= 0;
                            1: fractional <= 16'h5555;
                            2: fractional <= 16'hAAAA;
                            default: fractional <= 0;
                        endcase
                    end
                    6: begin
                        case (remainder)
                            0: fractional <= 0;
                            1: fractional <= 16'h2AAA;
                            2: fractional <= 16'h5555;
                            3: fractional <= 16'h8000;
                            4: fractional <= 16'hAAAA;
                            5: fractional <= 16'hD555;
                            default: fractional <= 0;
                        endcase
                    end
                    default: fractional <= 0;
                endcase
            end
            
            DONE: begin
                done <= 1;
                avg_distance <= {quotient[15:0], fractional};
                impossible <= (num_pairs == 0);
            end
        endcase
    end
end

endmodule