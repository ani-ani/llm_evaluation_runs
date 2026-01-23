module list_splitter (
    input clk,
    input rst_n,
    input start,
    input [3:0] step,
    input [4:0] num_elements,
    input [7:0] data_in,
    input data_valid,
    output reg [1:0] buffer_id,
    output reg [4:0] buffer_index,
    output reg [7:0] data_out,
    output reg write_enable,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam READ_ELEMENT = 2'b01;
    localparam PROCESS = 2'b10;
    localparam COMPLETE = 2'b11;

    reg [1:0] current_state, next_state;
    reg [4:0] element_counter, next_element_counter;
    reg [1:0] buffer_id_reg, next_buffer_id;
    reg [4:0] buffer_index_reg, next_buffer_index;

    // State Register and Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            element_counter <= 5'b0;
            buffer_id_reg <= 2'b0;
            buffer_index_reg <= 5'b0;
        end else begin
            current_state <= next_state;
            element_counter <= next_element_counter;
            buffer_id_reg <= next_buffer_id;
            buffer_index_reg <= next_buffer_index;
        end
    end

    // Next State Logic and Output Logic
    always @(*) begin
        // Default assignments to avoid latches
        next_state = current_state;
        next_element_counter = element_counter;
        next_buffer_id = buffer_id_reg;
        next_buffer_index = buffer_index_reg;
        
        buffer_id = buffer_id_reg;
        buffer_index = buffer_index_reg;
        data_out = 8'b0;
        write_enable = 1'b0;
        done = 1'b0;

        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = READ_ELEMENT;
                    next_element_counter = 5'b0;
                    next_buffer_id = 2'b0;
                    next_buffer_index = 5'b0;
                end
            end

            READ_ELEMENT: begin
                if (data_valid) begin
                    next_state = PROCESS;
                end
            end

            PROCESS: begin
                // Write current element to external logic
                buffer_id = buffer_id_reg;
                buffer_index = buffer_index_reg;
                data_out = data_in;
                write_enable = 1'b1;

                // Update counters for next element
                if (element_counter + 1 < num_elements) begin
                    next_element_counter = element_counter + 1;
                    
                    // Calculate next buffer_id (i % step)
                    // Assuming step 1-4, we can use simple addition logic
                    if (buffer_id_reg < step[1:0] - 1'b1 && step != 4'd0) begin
                        next_buffer_id = buffer_id_reg + 1'b1;
                    end else begin
                        next_buffer_id = 2'b0;
                    end

                    // Calculate next buffer_index (i / step)
                    // Increment buffer_index when wrapping around to buffer 0
                    if (buffer_id_reg == step[1:0] - 1'b1 || (step == 4'd1 && buffer_id_reg == 0)) begin
                        next_buffer_index = buffer_index_reg + 1'b1;
                    end else begin
                        next_buffer_index = buffer_index_reg;
                    end

                    next_state = READ_ELEMENT;
                end else begin
                    next_state = COMPLETE;
                end
            end

            COMPLETE: begin
                done = 1'b1;
                if (start) begin // Restart if start is asserted again
                    next_state = READ_ELEMENT;
                    next_element_counter = 5'b0;
                    next_buffer_id = 2'b0;
                    next_buffer_index = 5'b0;
                end else begin
                    next_state = IDLE;
                    next_element_counter = 5'b0;
                    next_buffer_id = 2'b0;
                    next_buffer_index = 5'b0;
                end
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule
