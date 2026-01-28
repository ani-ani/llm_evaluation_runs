module ArrayTrimmer (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] k_in,
    input wire [4:0] total_tuples,
    input wire [7:0] arr_in_0,
    input wire [7:0] arr_in_1,
    input wire [7:0] arr_in_2,
    input wire [7:0] arr_in_3,
    input wire [7:0] arr_in_4,
    input wire [7:0] arr_in_5,
    input wire [7:0] arr_in_6,
    input wire [7:0] arr_in_7,
    input wire [7:0] arr_in_8,
    input wire [7:0] arr_in_9,
    input wire [7:0] arr_in_10,
    input wire [7:0] arr_in_11,
    input wire [7:0] arr_in_12,
    input wire [7:0] arr_in_13,
    input wire [7:0] arr_in_14,
    input wire [7:0] arr_in_15,
    input wire [4:0] tuple_idx,
    input wire [3:0] element_idx,
    output reg [7:0] result,
    output reg done,
    output reg valid,
    output reg busy
);

    // Parameters
    parameter MAX_TUPLES = 16;
    parameter MAX_ELEMENTS = 16;

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SET_TRIM = 3'd1;
    localparam [2:0] PROCESS = 3'd2;
    localparam [2:0] COMPLETE = 3'd3;

    // Registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [4:0] current_tuple;
    reg [4:0] current_tuple_next;
    reg [3:0] current_element;
    reg [3:0] current_element_next;
    reg [3:0] k_reg;
    reg [3:0] k_reg_next;
    reg [4:0] total_tuples_reg;
    reg [4:0] total_tuples_reg_next;
    reg valid_next;
    reg done_next;
    reg busy_next;

    // Output storage: 16x16x8-bit
    reg [7:0] output_storage [0:15][0:15];

    // Input array mapping
    wire [7:0] arr_in [0:15];
    assign arr_in[0] = arr_in_0;
    assign arr_in[1] = arr_in_1;
    assign arr_in[2] = arr_in_2;
    assign arr_in[3] = arr_in_3;
    assign arr_in[4] = arr_in_4;
    assign arr_in[5] = arr_in_5;
    assign arr_in[6] = arr_in_6;
    assign arr_in[7] = arr_in_7;
    assign arr_in[8] = arr_in_8;
    assign arr_in[9] = arr_in_9;
    assign arr_in[10] = arr_in_10;
    assign arr_in[11] = arr_in_11;
    assign arr_in[12] = arr_in_12;
    assign arr_in[13] = arr_in_13;
    assign arr_in[14] = arr_in_14;
    assign arr_in[15] = arr_in_15;

    // Next state logic
    always @(*) begin
        next_state = state;
        current_tuple_next = current_tuple;
        current_element_next = current_element;
        k_reg_next = k_reg;
        total_tuples_reg_next = total_tuples_reg;
        valid_next = 1'b0;
        done_next = 1'b0;
        busy_next = 1'b1;

        case (state)
            IDLE: begin
                busy_next = 1'b0;
                if (start) begin
                    next_state = SET_TRIM;
                    current_tuple_next = 5'd0;
                    current_element_next = 4'd0;
                    k_reg_next = k_in;
                    total_tuples_reg_next = total_tuples;
                end
            end

            SET_TRIM: begin
                next_state = PROCESS;
            end

            PROCESS: begin
                busy_next = 1'b1;
                valid_next = 1'b1;

                // Increment element
                current_element_next = current_element + 4'd1;

                // If element reaches MAX_ELEMENTS, move to next tuple
                if (current_element == MAX_ELEMENTS - 4'd1) begin
                    current_element_next = 4'd0;
                    current_tuple_next = current_tuple + 5'd1;
                end

                // Check if all tuples processed
                if (current_tuple == total_tuples_reg - 5'd1 && current_element == MAX_ELEMENTS - 4'd1) begin
                    next_state = COMPLETE;
                end
            end

            COMPLETE: begin
                done_next = 1'b1;
                busy_next = 1'b0;
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Output logic
    always @(*) begin
        result = 8'd0;

        // Only output valid data during PROCESS state
        if (state == PROCESS) begin
            // Calculate if this element should be included in trimmed array
            // Original array indices: 0 to 15
            // Trim first k_reg elements and last k_reg elements
            // Output indices: k_reg to (16 - k_reg - 1)
            // For tuple_idx, element_idx: we're writing to output storage
            // For reading: we need to map current_element to output position

            if (k_reg < MAX_ELEMENTS) begin
                // Check if current_element is in valid trim range
                if (current_element >= k_reg && current_element < (MAX_ELEMENTS - k_reg)) begin
                    // Include this element in output
                    result = arr_in[current_element];
                end else begin
                    // This element is trimmed, output 0
                    result = 8'd0;
                end
            end else begin
                // k_in too large, all elements trimmed
                result = 8'd0;
            end
        end else if (state == IDLE || state == SET_TRIM || state == COMPLETE) begin
            // Read from output storage based on tuple_idx and element_idx
            // This allows reading any trimmed tuple/element
            if (tuple_idx < total_tuples_reg && element_idx < MAX_ELEMENTS) begin
                result = output_storage[tuple_idx][element_idx];
            end else begin
                result = 8'd0;
            end
        end else begin
            result = 8'd0;
        end
    end

    // Sequential logic
    integer i, j;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_tuple <= 5'd0;
            current_element <= 4'd0;
            k_reg <= 4'd0;
            total_tuples_reg <= 5'd0;
            valid <= 1'b0;
            done <= 1'b0;
            busy <= 1'b0;
            // Initialize output storage
            for (i = 0; i < 16; i = i + 1) begin
                for (j = 0; j < 16; j = j + 1) begin
                    output_storage[i][j] <= 8'd0;
                end
            end
        end else begin
            state <= next_state;
            current_tuple <= current_tuple_next;
            current_element <= current_element_next;
            k_reg <= k_reg_next;
            total_tuples_reg <= total_tuples_reg_next;
            valid <= valid_next;
            done <= done_next;
            busy <= busy_next;

            // Write to output storage during PROCESS state
            if (state == PROCESS) begin
                // Store the result in output storage
                // Map current_element to output position
                if (k_reg < MAX_ELEMENTS) begin
                    if (current_element >= k_reg && current_element < (MAX_ELEMENTS - k_reg)) begin
                        // Calculate output position
                        output_storage[current_tuple][current_element] <= arr_in[current_element];
                    end
                end
            end
        end
    end

endmodule