module median_finder(
    input clk,
    input rst_n,
    input start,
    input [15:0] data_in,
    input valid_in,
    input [2:0] index,
    input [3:0] count,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] LOADING   = 3'd1;
    localparam [2:0] SORTING   = 3'd2;
    localparam [2:0] COMPUTING = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;
    reg [3:0] load_counter;
    reg [3:0] sort_pass;
    reg [3:0] sort_index;
    reg [3:0] compute_counter;

    // Internal array storage (8 elements, 16-bit each)
    reg [15:0] array [0:7];
    integer i;

    // Bubble sort swap flag
    reg swap_occurred;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            load_counter <= 4'd0;
            sort_pass <= 4'd0;
            sort_index <= 4'd0;
            compute_counter <= 4'd0;
            swap_occurred <= 1'b0;
            done <= 1'b0;
            result <= 32'd0;
            for (i = 0; i < 8; i = i + 1) begin
                array[i] <= 16'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start && valid_in) begin
                    next_state = LOADING;
                end else begin
                    next_state = IDLE;
                end
            end

            LOADING: begin
                if (load_counter == count - 1) begin
                    next_state = SORTING;
                end else begin
                    next_state = LOADING;
                end
            end

            SORTING: begin
                if (sort_pass == 8'd7 && sort_index == 8'd7) begin
                    next_state = COMPUTING;
                end else begin
                    next_state = SORTING;
                end
            end

            COMPUTING: begin
                if (compute_counter == (count[0] ? 2'd1 : 2'd2) - 1) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = COMPUTING;
                end
            end

            DONE_STATE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Loading logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            load_counter <= 4'd0;
        end else begin
            if (state == LOADING && valid_in) begin
                array[index] <= data_in;
                load_counter <= load_counter + 4'd1;
            end
        end
    end

    // Sorting logic (bubble sort)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sort_pass <= 4'd0;
            sort_index <= 4'd0;
            swap_occurred <= 1'b0;
        end else begin
            if (state == SORTING) begin
                if (sort_index < 7 - sort_pass) begin
                    if (array[sort_index] > array[sort_index + 1]) begin
                        // Swap elements
                        reg [15:0] temp;
                        temp = array[sort_index];
                        array[sort_index] = array[sort_index + 1];
                        array[sort_index + 1] = temp;
                        swap_occurred = 1'b1;
                    end
                    sort_index <= sort_index + 4'd1;
                end else begin
                    sort_index <= 4'd0;
                    if (sort_pass < 7) begin
                        sort_pass <= sort_pass + 4'd1;
                    end
                end
            end
        end
    end

    // Computing logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            compute_counter <= 4'd0;
            result <= 32'd0;
        end else begin
            if (state == COMPUTING) begin
                if (count[0]) begin // Odd count
                    if (compute_counter == 0) begin
                        result <= {16'd0, array[count/2]};
                    end
                end else begin // Even count
                    if (compute_counter == 0) begin
                        result <= {16'd0, array[count/2 - 1]} + {16'd0, array[count/2]};
                    end else begin
                        result <= result >> 1; // Divide by 2
                    end
                end
                compute_counter <= compute_counter + 4'd1;
            end
        end
    end

    // Done signal logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
        end else begin
            if (state == DONE_STATE) begin
                done <= 1'b1;
            end else begin
                done <= 1'b0;
            end
        end
    end

endmodule