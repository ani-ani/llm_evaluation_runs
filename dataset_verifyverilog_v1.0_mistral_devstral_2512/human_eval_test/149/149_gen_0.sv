module sorted_list_sum(
    input clk,
    input rst_n,
    input start,
    input [7:0] strings_in [0:7],
    output reg [7:0] result [0:7],
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] FILTER    = 3'd1;
    localparam [2:0] SORT_PASS = 3'd2;
    localparam [2:0] DONE_STATE = 3'd3;

    reg [2:0] state;
    reg [7:0] temp_buffer [0:7];
    reg [7:0] sorted_buffer [0:7];
    reg [3:0] valid_count;
    reg [3:0] pass_count;
    reg [3:0] i;
    reg [3:0] j;
    reg [3:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd50;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            cycle_count <= 8'd0;
            valid_count <= 4'd0;
            pass_count <= 4'd0;
            i <= 4'd0;
            j <= 4'd0;
            // Initialize result array
            integer k;
            for (k = 0; k < 8; k = k + 1) begin
                result[k] <= 8'd0;
                temp_buffer[k] <= 8'd0;
                sorted_buffer[k] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= FILTER;
                    end
                end

                FILTER: begin
                    cycle_count <= cycle_count + 8'd1;
                    valid_count <= 4'd0;
                    // Filter strings with even length (LSB = 0)
                    integer k;
                    for (k = 0; k < 8; k = k + 1) begin
                        if (strings_in[k][0] == 1'b0) begin
                            temp_buffer[valid_count] <= strings_in[k];
                            valid_count <= valid_count + 4'd1;
                        end
                    end
                    state <= SORT_PASS;
                    pass_count <= 4'd0;
                end

                SORT_PASS: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (pass_count < valid_count - 4'd1) begin
                        // Perform one pass of bubble sort
                        for (j = 4'd0; j < valid_count - pass_count - 4'd1; j = j + 4'd1) begin
                            if (temp_buffer[j] > temp_buffer[j + 4'd1]) begin
                                // Swap
                                sorted_buffer[j] <= temp_buffer[j + 4'd1];
                                sorted_buffer[j + 4'd1] <= temp_buffer[j];
                            end else begin
                                sorted_buffer[j] <= temp_buffer[j];
                                sorted_buffer[j + 4'd1] <= temp_buffer[j + 4'd1];
                            end
                        end
                        // Copy back to temp_buffer
                        for (j = 4'd0; j < valid_count; j = j + 4'd1) begin
                            temp_buffer[j] <= sorted_buffer[j];
                        end
                        pass_count <= pass_count + 4'd1;
                    end else begin
                        // Copy sorted results to output
                        for (j = 4'd0; j < 8; j = j + 4'd1) begin
                            if (j < valid_count) begin
                                result[j] <= temp_buffer[j];
                            end else begin
                                result[j] <= 8'd0;
                            end
                        end
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule