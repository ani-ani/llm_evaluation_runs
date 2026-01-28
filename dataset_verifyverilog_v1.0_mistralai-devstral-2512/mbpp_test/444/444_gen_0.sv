module array_trimmer(
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
    localparam [3:0] MAX_ELEMENTS = 4'd16;
    localparam [3:0] MAX_TUPLES = 4'd16;

    // FSM States
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SET_TRIM = 3'd1;
    localparam [2:0] PROCESS = 3'd2;
    localparam [2:0] COMPLETE = 3'd3;

    // Internal registers
    reg [2:0] state, next_state;
    reg [4:0] current_tuple;
    reg [3:0] current_element;
    reg [3:0] k_reg;
    reg [4:0] total_tuples_reg;
    reg [7:0] input_array [0:15];
    reg [7:0] output_array [0:15];
    reg [3:0] output_length;
    reg [3:0] output_index;
    reg [3:0] read_index;
    reg [3:0] write_index;
    reg [3:0] trim_start;
    reg [3:0] trim_end;
    reg [3:0] i;

    // FSM State Transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            valid <= 1'b0;
            busy <= 1'b0;
            current_tuple <= 5'd0;
            current_element <= 4'd0;
            k_reg <= 4'd0;
            total_tuples_reg <= 5'd0;
            output_length <= 4'd0;
            output_index <= 4'd0;
            read_index <= 4'd0;
            write_index <= 4'd0;
            trim_start <= 4'd0;
            trim_end <= 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                input_array[i] <= 8'd0;
                output_array[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // Next State Logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = SET_TRIM;
                end
            end
            SET_TRIM: begin
                next_state = PROCESS;
            end
            PROCESS: begin
                if (current_tuple == total_tuples_reg - 1 && output_index == output_length - 1) begin
                    next_state = COMPLETE;
                end
            end
            COMPLETE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Output Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 8'd0;
            done <= 1'b0;
            valid <= 1'b0;
            busy <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    busy <= 1'b0;
                end
                SET_TRIM: begin
                    k_reg <= k_in;
                    total_tuples_reg <= total_tuples;
                    busy <= 1'b1;
                    valid <= 1'b0;
                    done <= 1'b0;
                    // Initialize arrays
                    for (i = 0; i < 16; i = i + 1) begin
                        input_array[i] <= 8'd0;
                        output_array[i] <= 8'd0;
                    end
                end
                PROCESS: begin
                    busy <= 1'b1;
                    done <= 1'b0;
                    // Read input array
                    if (current_element < 16) begin
                        case (current_element)
                            4'd0: input_array[current_element] <= arr_in_0;
                            4'd1: input_array[current_element] <= arr_in_1;
                            4'd2: input_array[current_element] <= arr_in_2;
                            4'd3: input_array[current_element] <= arr_in_3;
                            4'd4: input_array[current_element] <= arr_in_4;
                            4'd5: input_array[current_element] <= arr_in_5;
                            4'd6: input_array[current_element] <= arr_in_6;
                            4'd7: input_array[current_element] <= arr_in_7;
                            4'd8: input_array[current_element] <= arr_in_8;
                            4'd9: input_array[current_element] <= arr_in_9;
                            4'd10: input_array[current_element] <= arr_in_10;
                            4'd11: input_array[current_element] <= arr_in_11;
                            4'd12: input_array[current_element] <= arr_in_12;
                            4'd13: input_array[current_element] <= arr_in_13;
                            4'd14: input_array[current_element] <= arr_in_14;
                            4'd15: input_array[current_element] <= arr_in_15;
                            default: input_array[current_element] <= 8'd0;
                        endcase
                        current_element <= current_element + 1'b1;
                    end else begin
                        // Trim operation
                        trim_start <= k_reg;
                        trim_end <= 16 - k_reg - 1;
                        output_length <= trim_end - trim_start + 1;
                        
                        if (output_length > 0) begin
                            if (output_index < output_length) begin
                                read_index <= trim_start + output_index;
                                output_array[output_index] <= input_array[read_index];
                                output_index <= output_index + 1'b1;
                                valid <= 1'b1;
                                result <= output_array[output_index];
                            end else begin
                                // Move to next tuple
                                current_tuple <= current_tuple + 1'b1;
                                current_element <= 4'd0;
                                output_index <= 4'd0;
                                valid <= 1'b0;
                            end
                        end else begin
                            // Output length is 0, move to next tuple
                            current_tuple <= current_tuple + 1'b1;
                            current_element <= 4'd0;
                            output_index <= 4'd0;
                            valid <= 1'b0;
                        end
                    end
                end
                COMPLETE: begin
                    done <= 1'b1;
                    valid <= 1'b0;
                    busy <= 1'b0;
                end
                default: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    busy <= 1'b0;
                end
            endcase
        end
    end

endmodule