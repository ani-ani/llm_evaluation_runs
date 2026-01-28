module dictionary_filter(
    input clk,
    input rst_n,
    input start,
    input [7:0] threshold,
    input [7:0] key_in [0:7],
    input [7:0] value_in [0:7],
    input [7:0] valid_in,
    output reg [7:0] key_out [0:7],
    output reg [7:0] value_out [0:7],
    output reg [7:0] valid_out,
    output reg [3:0] count,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] READ    = 3'd1;
    localparam [2:0] FILTER  = 3'd2;
    localparam [2:0] OUTPUT  = 3'd3;
    localparam [2:0] COMPLETE = 3'd4;

    reg [2:0] state, next_state;
    reg [3:0] index;
    reg [3:0] filtered_count;
    reg [7:0] temp_key [0:7];
    reg [7:0] temp_value [0:7];
    reg [7:0] temp_valid;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd20;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            index <= 4'd0;
            filtered_count <= 4'd0;
            count <= 4'd0;
            done <= 1'b0;
            cycle_count <= 4'd0;

            // Initialize output arrays
            integer i;
            for (i = 0; i < 8; i = i + 1) begin
                key_out[i] <= 8'd0;
                value_out[i] <= 8'd0;
                valid_out[i] <= 1'b0;
                temp_key[i] <= 8'd0;
                temp_value[i] <= 8'd0;
            end
            temp_valid <= 8'd0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        next_state <= READ;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                READ: begin
                    cycle_count <= cycle_count + 4'd1;
                    index <= 4'd0;
                    filtered_count <= 4'd0;
                    next_state <= FILTER;
                end

                FILTER: begin
                    cycle_count <= cycle_count + 4'd1;

                    // Check if current entry is valid and meets threshold
                    if (valid_in[index] && (value_in[index] >= threshold)) begin
                        temp_key[filtered_count] <= key_in[index];
                        temp_value[filtered_count] <= value_in[index];
                        temp_valid[filtered_count] <= 1'b1;
                        filtered_count <= filtered_count + 4'd1;
                    end

                    // Move to next index
                    if (index == 4'd7) begin
                        next_state <= OUTPUT;
                    end else begin
                        index <= index + 4'd1;
                        next_state <= FILTER;
                    end
                end

                OUTPUT: begin
                    cycle_count <= cycle_count + 4'd1;

                    // Copy filtered results to output
                    integer i;
                    for (i = 0; i < 8; i = i + 1) begin
                        if (i < filtered_count) begin
                            key_out[i] <= temp_key[i];
                            value_out[i] <= temp_value[i];
                            valid_out[i] <= temp_valid[i];
                        end else begin
                            key_out[i] <= 8'd0;
                            value_out[i] <= 8'd0;
                            valid_out[i] <= 1'b0;
                        end
                    end

                    count <= filtered_count;
                    next_state <= COMPLETE;
                end

                COMPLETE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

    // Safety: prevent infinite loops
    always @(posedge clk) begin
        if (cycle_count >= MAX_CYCLES && state != IDLE) begin
            next_state <= IDLE;
            done <= 1'b1;
        end
    end

endmodule