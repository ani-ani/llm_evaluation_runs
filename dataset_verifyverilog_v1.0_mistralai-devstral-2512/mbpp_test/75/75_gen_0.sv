module TupleFilter(
    input clk,
    input rst_n,
    input start,
    input [7:0] tuple_data,
    input [2:0] element_index,
    input [1:0] tuple_index,
    input [7:0] K,
    output reg [7:0] filtered_tuple,
    output reg filtered_valid,
    output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] READ_TUPLE = 2'd1;
    localparam [1:0] CHECK_DIVISIBILITY = 2'd2;
    localparam [1:0] OUTPUT_TUPLE = 2'd3;

    localparam [1:0] TUPLE_COUNT = 2'd4;
    localparam [2:0] TUPLE_WIDTH = 3'd3;
    localparam [7:0] DATA_WIDTH = 8'd8;

    reg [1:0] state, next_state;
    reg [1:0] current_tuple;
    reg [2:0] current_element;
    reg [7:0] tuple_buffer [0:2];
    reg [7:0] output_buffer [0:2];
    reg tuple_pass;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd50;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_tuple <= 2'd0;
            current_element <= 3'd0;
            filtered_tuple <= 8'd0;
            filtered_valid <= 1'b0;
            done <= 1'b0;
            tuple_pass <= 1'b0;
            cycle_count <= 8'd0;
            for (integer i = 0; i < 3; i = i + 1) begin
                tuple_buffer[i] <= 8'd0;
                output_buffer[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    filtered_valid <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        current_tuple <= 2'd0;
                        current_element <= 3'd0;
                        next_state <= READ_TUPLE;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                READ_TUPLE: begin
                    cycle_count <= cycle_count + 8'd1;
                    tuple_buffer[current_element] <= tuple_data;
                    if (current_element == TUPLE_WIDTH - 1) begin
                        next_state <= CHECK_DIVISIBILITY;
                    end else begin
                        current_element <= current_element + 3'd1;
                        next_state <= READ_TUPLE;
                    end
                end

                CHECK_DIVISIBILITY: begin
                    cycle_count <= cycle_count + 8'd1;
                    tuple_pass <= 1'b1;
                    for (integer i = 0; i < 3; i = i + 1) begin
                        if (tuple_buffer[i] % K != 0) begin
                            tuple_pass <= 1'b0;
                        end
                    end
                    if (tuple_pass) begin
                        for (integer i = 0; i < 3; i = i + 1) begin
                            output_buffer[i] <= tuple_buffer[i];
                        end
                    end
                    current_element <= 3'd0;
                    if (current_tuple == TUPLE_COUNT - 1) begin
                        if (tuple_pass) begin
                            next_state <= OUTPUT_TUPLE;
                        end else begin
                            next_state <= IDLE;
                            done <= 1'b1;
                        end
                    end else begin
                        current_tuple <= current_tuple + 2'd1;
                        if (tuple_pass) begin
                            next_state <= OUTPUT_TUPLE;
                        end else begin
                            next_state <= READ_TUPLE;
                        end
                    end
                end

                OUTPUT_TUPLE: begin
                    cycle_count <= cycle_count + 8'd1;
                    filtered_tuple <= output_buffer[current_element];
                    filtered_valid <= 1'b1;
                    if (current_element == TUPLE_WIDTH - 1) begin
                        filtered_valid <= 1'b0;
                        if (current_tuple == TUPLE_COUNT - 1) begin
                            next_state <= IDLE;
                            done <= 1'b1;
                        end else begin
                            current_tuple <= current_tuple + 2'd1;
                            current_element <= 3'd0;
                            next_state <= READ_TUPLE;
                        end
                    end else begin
                        current_element <= current_element + 3'd1;
                        next_state <= OUTPUT_TUPLE;
                    end
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    filtered_valid <= 1'b0;
                    filtered_tuple <= 8'd0;
                end
            endcase
        end
    end

endmodule