module sort_numbers(
    input clk,
    input rst_n,
    input start,
    input [3:0] numbers [0:7],
    input [2:0] valid_count,
    output reg [3:0] result [0:7],
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] SORTING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    // Internal registers
    reg [1:0] state, next_state;
    reg [3:0] internal_array [0:7];
    reg [2:0] pass_counter;
    reg [2:0] index_counter;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd64;

    // Initialize all registers
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            pass_counter <= 3'd0;
            index_counter <= 3'd0;
            cycle_count <= 8'd0;
            for (i = 0; i < 8; i = i + 1) begin
                internal_array[i] <= 4'd0;
                result[i] <= 4'd0;
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        // Copy input to internal array
                        for (i = 0; i < 8; i = i + 1) begin
                            internal_array[i] <= numbers[i];
                        end
                        next_state <= SORTING;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                SORTING: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Bubble sort logic
                    if (index_counter < (valid_count - 2 - pass_counter)) begin
                        // Compare and swap
                        if (internal_array[index_counter] > internal_array[index_counter + 1]) begin
                            reg [3:0] temp;
                            temp = internal_array[index_counter];
                            internal_array[index_counter] = internal_array[index_counter + 1];
                            internal_array[index_counter + 1] = temp;
                        end
                        index_counter <= index_counter + 3'd1;
                    end else begin
                        // Move to next pass
                        index_counter <= 3'd0;
                        if (pass_counter < (valid_count - 2)) begin
                            pass_counter <= pass_counter + 3'd1;
                        end else begin
                            // All passes complete
                            pass_counter <= 3'd0;
                            next_state <= DONE_STATE;
                        end
                    end
                    
                    // Safety: prevent infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    // Copy sorted array to output
                    for (i = 0; i < 8; i = i + 1) begin
                        result[i] <= internal_array[i];
                    end
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

endmodule