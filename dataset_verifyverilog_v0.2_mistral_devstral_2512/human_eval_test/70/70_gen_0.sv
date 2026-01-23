module strange_sort (
    input clk,
    input rst_n,
    input [7:0] data_in,
    input valid_in,
    input start,
    output reg [7:0] data_out,
    output reg valid_out,
    output reg done
);

    // States
    typedef enum logic [2:0] {
        IDLE,
        LOADING,
        SORTING,
        OUTPUT
    } state_t;

    state_t state, next_state;

    // Internal registers
    reg [7:0] buffer [0:7];
    reg [7:0] valid_mask;
    reg [2:0] count;
    reg [2:0] output_index;
    reg [7:0] sorted_buffer [0:7];
    reg min_max_flag; // 0: find min, 1: find max

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            count <= 0;
            valid_mask <= 0;
            output_index <= 0;
            min_max_flag <= 0;
            data_out <= 0;
            valid_out <= 0;
            done <= 0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = LOADING;
            end
            LOADING: begin
                if (count == 7) next_state = SORTING;
                else if (!valid_in && start) next_state = SORTING;
            end
            SORTING: begin
                if (output_index == 7) next_state = OUTPUT;
            end
            OUTPUT: begin
                if (output_index == 7) next_state = IDLE;
            end
        endcase
    end

    // Loading logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= 0;
            valid_mask <= 0;
        end else if (state == LOADING && valid_in) begin
            buffer[count] <= data_in;
            valid_mask[count] <= 1'b1;
            count <= count + 1;
        end
    end

    // Sorting logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            output_index <= 0;
            min_max_flag <= 0;
        end else if (state == SORTING) begin
            // Find min or max among valid elements
            reg [7:0] extreme_value;
            reg [2:0] extreme_index;
            reg first_valid = 1'b1;

            for (int i = 0; i < 8; i++) begin
                if (valid_mask[i]) begin
                    if (first_valid) begin
                        extreme_value = buffer[i];
                        extreme_index = i;
                        first_valid = 1'b0;
                    end else begin
                        if (min_max_flag) begin // Find max
                            if (buffer[i] > extreme_value) begin
                                extreme_value = buffer[i];
                                extreme_index = i;
                            end
                        end else begin // Find min
                            if (buffer[i] < extreme_value) begin
                                extreme_value = buffer[i];
                                extreme_index = i;
                            end
                        end
                    end
                end
            end

            sorted_buffer[output_index] = extreme_value;
            valid_mask[extreme_index] = 1'b0;
            output_index = output_index + 1;
            min_max_flag = ~min_max_flag;
        end
    end

    // Output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out <= 0;
            valid_out <= 0;
            done <= 0;
        end else begin
            data_out <= 0;
            valid_out <= 0;
            done <= 0;

            if (state == OUTPUT) begin
                data_out <= sorted_buffer[output_index];
                valid_out <= 1'b1;
                if (output_index == 7) done <= 1'b1;
                else output_index <= output_index + 1;
            end
        end
    end

endmodule