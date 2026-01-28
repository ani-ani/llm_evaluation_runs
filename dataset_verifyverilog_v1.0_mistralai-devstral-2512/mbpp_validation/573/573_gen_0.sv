module UniqueProductCalculator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] len,
    input wire [7:0] arr_0,
    input wire [7:0] arr_1,
    input wire [7:0] arr_2,
    input wire [7:0] arr_3,
    input wire [7:0] arr_4,
    input wire [7:0] arr_5,
    input wire [7:0] arr_6,
    input wire [7:0] arr_7,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] LOAD      = 3'd1;
    localparam [2:0] SORT      = 3'd2;
    localparam [2:0] FILTER    = 3'd3;
    localparam [2:0] MULTIPLY  = 3'd4;
    localparam [2:0] FINISH    = 3'd5;

    reg [2:0] state, next_state;

    // Internal registers
    reg [7:0] sorted_array [0:7];
    reg [7:0] unique_array [0:7];
    reg [3:0] unique_count;
    reg [3:0] multiply_index;
    reg [32:0] product_temp;
    reg [7:0] current_value;
    reg [3:0] sort_pass;
    reg [3:0] sort_index;
    reg [3:0] filter_index;
    reg [3:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            sort_pass <= 4'd0;
            sort_index <= 4'd0;
            filter_index <= 4'd0;
            multiply_index <= 4'd0;
            unique_count <= 4'd0;
            product_temp <= 33'd0;
            current_value <= 8'd0;
            for (integer i = 0; i < 8; i = i + 1) begin
                sorted_array[i] <= 8'd0;
                unique_array[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD;
                end else begin
                    next_state = IDLE;
                end
            end

            LOAD: begin
                next_state = SORT;
            end

            SORT: begin
                if (sort_pass == 4'd7 && sort_index == 4'd7) begin
                    next_state = FILTER;
                end else begin
                    next_state = SORT;
                end
            end

            FILTER: begin
                if (filter_index == 4'd7) begin
                    next_state = MULTIPLY;
                end else begin
                    next_state = FILTER;
                end
            end

            MULTIPLY: begin
                if (multiply_index == unique_count) begin
                    next_state = FINISH;
                end else begin
                    next_state = MULTIPLY;
                end
            end

            FINISH: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Load input array
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialized in reset block
        end else if (state == LOAD) begin
            sorted_array[0] <= arr_0;
            sorted_array[1] <= arr_1;
            sorted_array[2] <= arr_2;
            sorted_array[3] <= arr_3;
            sorted_array[4] <= arr_4;
            sorted_array[5] <= arr_5;
            sorted_array[6] <= arr_6;
            sorted_array[7] <= arr_7;
            sort_pass <= 4'd0;
            sort_index <= 4'd0;
        end
    end

    // Bubble sort implementation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialized in reset block
        end else if (state == SORT) begin
            if (sort_index < len - 1) begin
                if (sorted_array[sort_index] > sorted_array[sort_index + 1]) begin
                    // Swap
                    reg [7:0] temp;
                    temp = sorted_array[sort_index];
                    sorted_array[sort_index] = sorted_array[sort_index + 1];
                    sorted_array[sort_index + 1] = temp;
                end
                sort_index <= sort_index + 4'd1;
            end else begin
                sort_index <= 4'd0;
                sort_pass <= sort_pass + 4'd1;
            end
        end
    end

    // Filter unique values
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialized in reset block
        end else if (state == FILTER) begin
            if (filter_index == 4'd0) begin
                unique_array[0] <= sorted_array[0];
                unique_count <= 4'd1;
                filter_index <= 4'd1;
            end else if (filter_index < len) begin
                if (sorted_array[filter_index] != sorted_array[filter_index - 1]) begin
                    unique_array[unique_count] <= sorted_array[filter_index];
                    unique_count <= unique_count + 4'd1;
                end
                filter_index <= filter_index + 4'd1;
            end
        end
    end

    // Multiplication stage
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialized in reset block
        end else if (state == MULTIPLY) begin
            if (multiply_index == 4'd0) begin
                product_temp <= 33'd0;
                multiply_index <= 4'd1;
            end else if (multiply_index <= unique_count) begin
                current_value <= unique_array[multiply_index - 1];
                product_temp <= product_temp + (current_value * product_temp[32:8]);
                multiply_index <= multiply_index + 4'd1;
            end
        end
    end

    // Output stage
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 32'd0;
            done <= 1'b0;
        end else if (state == FINISH) begin
            result <= product_temp[32:1];
            done <= 1'b1;
        end else begin
            done <= 1'b0;
        end
    end

    // Safety: prevent infinite loops
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 8'd0;
        end else if (cycle_count >= MAX_CYCLES) begin
            state <= IDLE;
            done <= 1'b1;
            result <= 32'd0;
            cycle_count <= 8'd0;
        end
    end

endmodule