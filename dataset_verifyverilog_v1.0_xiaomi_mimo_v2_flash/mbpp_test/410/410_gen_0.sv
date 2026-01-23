module find_min_heterogeneous(
    input clk,
    input rst_n,
    input start,
    input [0:7] valid,
    input [0:7] type_code,
    input [0:7][7:0] value,
    input [2:0] num_elements,
    output reg [7:0] min_value,
    output reg done,
    output reg error
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SCAN = 3'd1;
    localparam [2:0] UPDATE = 3'd2;
    localparam [2:0] DONE_STATE = 3'd3;
    localparam [2:0] ERROR_STATE = 3'd4;

    // Internal registers and wires
    reg [2:0] state, next_state;
    reg [2:0] index;
    reg [7:0] current_min;
    reg min_initialized;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Type code constants
    localparam [0:0] TYPE_INT = 1'b0;
    localparam [0:0] TYPE_STRING = 1'b1;

    // Sequential state transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            min_value <= 8'd0;
            done <= 1'b0;
            error <= 1'b0;
            index <= 3'd0;
            current_min <= 8'd0;
            min_initialized <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    error <= 1'b0;
                    index <= 3'd0;
                    cycle_count <= 8'd0;
                    min_initialized <= 1'b0;
                    if (start) begin
                        state <= SCAN;
                    end
                end

                SCAN: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (index < num_elements && cycle_count < MAX_CYCLES) begin
                        // Check if current element is valid and is an integer
                        if (valid[index] && (type_code[index] == TYPE_INT)) begin
                            state <= UPDATE;
                        end else begin
                            // Skip this element, move to next
                            if (index < num_elements - 3'd1) begin
                                index <= index + 3'd1;
                            end else begin
                                // End of array reached
                                if (min_initialized) begin
                                    state <= DONE_STATE;
                                end else begin
                                    state <= ERROR_STATE;
                                end
                            end
                        end
                    end else begin
                        // End of array or timeout
                        if (min_initialized) begin
                            state <= DONE_STATE;
                        end else begin
                            state <= ERROR_STATE;
                        end
                    end
                end

                UPDATE: begin
                    // Compare current value with minimum
                    if (!min_initialized) begin
                        current_min <= value[index];
                        min_initialized <= 1'b1;
                    end else if (value[index] < current_min) begin
                        current_min <= value[index];
                    end
                    
                    // Move to next element
                    if (index < num_elements - 3'd1) begin
                        index <= index + 3'd1;
                        state <= SCAN;
                    end else begin
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    min_value <= current_min;
                    done <= 1'b1;
                    state <= IDLE;
                end

                ERROR_STATE: begin
                    error <= 1'b1;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule