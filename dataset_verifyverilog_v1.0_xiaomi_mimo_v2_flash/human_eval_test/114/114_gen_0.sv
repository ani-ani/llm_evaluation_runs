module min_subarray_sum (
    input clk,
    input rst_n,
    input start,
    input signed [15:0] arr [0:7],
    output reg signed [15:0] result,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE      = 4'd0;
    localparam [3:0] LOAD      = 4'd1;
    localparam [3:0] COMPUTE_0 = 4'd2;
    localparam [3:0] COMPUTE_1 = 4'd3;
    localparam [3:0] COMPUTE_2 = 4'd4;
    localparam [3:0] COMPUTE_3 = 4'd5;
    localparam [3:0] COMPUTE_4 = 4'd6;
    localparam [3:0] COMPUTE_5 = 4'd7;
    localparam [3:0] COMPUTE_6 = 4'd8;
    localparam [3:0] COMPUTE_7 = 4'd9;
    localparam [3:0] DONE      = 4'd10;

    reg [3:0] state;
    reg [3:0] next_state;
    reg [2:0] index;
    reg signed [15:0] min_so_far;
    reg signed [15:0] current_min;
    reg signed [15:0] element_reg;
    reg signed [15:0] sum_temp;

    // Combinational next state logic
    always @(*) begin
        case (state)
            IDLE:       next_state = start ? LOAD : IDLE;
            LOAD:       next_state = COMPUTE_0;
            COMPUTE_0:  next_state = COMPUTE_1;
            COMPUTE_1:  next_state = COMPUTE_2;
            COMPUTE_2:  next_state = COMPUTE_3;
            COMPUTE_3:  next_state = COMPUTE_4;
            COMPUTE_4:  next_state = COMPUTE_5;
            COMPUTE_5:  next_state = COMPUTE_6;
            COMPUTE_6:  next_state = COMPUTE_7;
            COMPUTE_7:  next_state = DONE;
            DONE:       next_state = IDLE;
            default:    next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'sd0;
            done <= 1'b0;
            index <= 3'd0;
            min_so_far <= 16'sd0;
            current_min <= 16'sd0;
            element_reg <= 16'sd0;
            sum_temp <= 16'sd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 16'sd0;
                end

                LOAD: begin
                    // Load first element into current_min and min_so_far
                    element_reg <= arr[0];
                    current_min <= arr[0];
                    min_so_far <= arr[0];
                    index <= 3'd1;
                end

                COMPUTE_0: begin
                    element_reg <= arr[1];
                    // current_min = min(element, current_min + element)
                    if (current_min + arr[1] < arr[1]) begin
                        current_min <= current_min + arr[1];
                    end else begin
                        current_min <= arr[1];
                    end
                    // Update min_so_far after current_min is updated
                    sum_temp <= current_min + arr[1];
                    index <= 3'd2;
                end

                COMPUTE_1: begin
                    element_reg <= arr[2];
                    // Use sum_temp from previous cycle
                    if (sum_temp < arr[2]) begin
                        current_min <= sum_temp;
                    end else begin
                        current_min <= arr[2];
                    end
                    // Update min_so_far with previous current_min
                    if (current_min < min_so_far) begin
                        min_so_far <= current_min;
                    end
                    sum_temp <= current_min + arr[2];
                    index <= 3'd3;
                end

                COMPUTE_2: begin
                    element_reg <= arr[3];
                    if (sum_temp < arr[3]) begin
                        current_min <= sum_temp;
                    end else begin
                        current_min <= arr[3];
                    end
                    if (current_min < min_so_far) begin
                        min_so_far <= current_min;
                    end
                    sum_temp <= current_min + arr[3];
                    index <= 3'd4;
                end

                COMPUTE_3: begin
                    element_reg <= arr[4];
                    if (sum_temp < arr[4]) begin
                        current_min <= sum_temp;
                    end else begin
                        current_min <= arr[4];
                    end
                    if (current_min < min_so_far) begin
                        min_so_far <= current_min;
                    end
                    sum_temp <= current_min + arr[4];
                    index <= 3'd5;
                end

                COMPUTE_4: begin
                    element_reg <= arr[5];
                    if (sum_temp < arr[5]) begin
                        current_min <= sum_temp;
                    end else begin
                        current_min <= arr[5];
                    end
                    if (current_min < min_so_far) begin
                        min_so_far <= current_min;
                    end
                    sum_temp <= current_min + arr[5];
                    index <= 3'd6;
                end

                COMPUTE_5: begin
                    element_reg <= arr[6];
                    if (sum_temp < arr[6]) begin
                        current_min <= sum_temp;
                    end else begin
                        current_min <= arr[6];
                    end
                    if (current_min < min_so_far) begin
                        min_so_far <= current_min;
                    end
                    sum_temp <= current_min + arr[6];
                    index <= 3'd7;
                end

                COMPUTE_6: begin
                    element_reg <= arr[7];
                    if (sum_temp < arr[7]) begin
                        current_min <= sum_temp;
                    end else begin
                        current_min <= arr[7];
                    end
                    if (current_min < min_so_far) begin
                        min_so_far <= current_min;
                    end
                    // No next element, prepare for DONE
                    index <= 3'd0;
                end

                COMPUTE_7: begin
                    // Final update for last element
                    if (current_min < min_so_far) begin
                        result <= current_min;
                    end else begin
                        result <= min_so_far;
                    end
                    done <= 1'b1;
                end

                DONE: begin
                    done <= 1'b0;
                end

                default: begin
                    state <= IDLE;
                    result <= 16'sd0;
                    done <= 1'b0;
                    index <= 3'd0;
                    min_so_far <= 16'sd0;
                    current_min <= 16'sd0;
                    element_reg <= 16'sd0;
                    sum_temp <= 16'sd0;
                end
            endcase
        end
    end

endmodule