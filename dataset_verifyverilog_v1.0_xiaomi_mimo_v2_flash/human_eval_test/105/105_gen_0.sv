module by_length_processor (
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:7],
    output reg [31:0] result_0, result_1, result_2, result_3,
    output reg [31:0] result_4, result_5, result_6, result_7,
    output reg [3:0] valid_count,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] FILTER  = 3'd1;
    localparam [2:0] SORT    = 3'd2;
    localparam [2:0] REVERSE = 3'd3;
    localparam [2:0] MAP     = 3'd4;
    localparam [2:0] DONE    = 3'd5;

    // String constants
    localparam [31:0] STR_ONE   = 32'h4F6E6500;
    localparam [31:0] STR_TWO   = 32'h54776F00;
    localparam [31:0] STR_THREE = 32'h54687265;  // + null in logic
    localparam [31:0] STR_FOUR  = 32'h466F7572;
    localparam [31:0] STR_FIVE  = 32'h46697665;
    localparam [31:0] STR_SIX   = 32'h53697800;
    localparam [31:0] STR_SEVEN = 32'h53657665;  // + null in logic
    localparam [31:0] STR_EIGHT = 32'h45696768;
    localparam [31:0] STR_NINE  = 32'h4E696E65;

    reg [2:0] state;
    reg [2:0] next_state;
    
    // Filter registers
    reg [7:0] temp_buf [0:7];
    reg [3:0] idx_in;
    reg [3:0] idx_out;
    reg [3:0] count;
    
    // Sort registers
    reg [2:0] i;
    reg [2:0] j;
    reg [7:0] temp_val;
    
    // Reverse registers
    reg [3:0] rev_idx;
    reg [7:0] rev_temp;
    
    // Map registers
    reg [3:0] map_idx;
    
    // Cycle counter for timeout
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    integer k;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            valid_count <= 4'd0;
            result_0 <= 32'd0;
            result_1 <= 32'd0;
            result_2 <= 32'd0;
            result_3 <= 32'd0;
            result_4 <= 32'd0;
            result_5 <= 32'd0;
            result_6 <= 32'd0;
            result_7 <= 32'd0;
            idx_in <= 4'd0;
            idx_out <= 4'd0;
            count <= 4'd0;
            i <= 3'd0;
            j <= 3'd0;
            rev_idx <= 4'd0;
            map_idx <= 4'd0;
            cycle_count <= 8'd0;
            for (k = 0; k < 8; k = k + 1) begin
                temp_buf[k] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    idx_in <= 4'd0;
                    idx_out <= 4'd0;
                    count <= 4'd0;
                    i <= 3'd0;
                    j <= 3'd0;
                    rev_idx <= 4'd0;
                    map_idx <= 4'd0;
                    if (start) begin
                        state <= FILTER;
                    end
                end

                FILTER: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE;
                    end else if (idx_in < 4'd8) begin
                        // Check if value is between 1 and 9
                        if ((arr[idx_in] >= 8'd1) && (arr[idx_in] <= 8'd9)) begin
                            temp_buf[idx_out] <= arr[idx_in];
                            count <= count + 4'd1;
                            idx_out <= idx_out + 4'd1;
                        end
                        idx_in <= idx_in + 4'd1;
                    end else begin
                        // Done filtering, move to sort
                        state <= SORT;
                        // Reset indices for sorting
                        i <= 3'd0;
                    end
                end

                SORT: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE;
                    end else if (count > 4'd1) begin
                        // Bubble sort: outer loop
                        if (i < count - 4'd1) begin
                            j <= 3'd0;
                            state <= SORT;
                        end else begin
                            // Sort complete
                            state <= REVERSE;
                        end
                    end else begin
                        // 0 or 1 elements, skip sort
                        state <= REVERSE;
                    end
                end

                SORT: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE;
                    end else begin
                        // Inner loop of bubble sort
                        if (j < count - 4'd1) begin
                            if (temp_buf[j] > temp_buf[j + 4'd1]) begin
                                // Swap
                                temp_val <= temp_buf[j];
                                temp_buf[j] <= temp_buf[j + 4'd1];
                                temp_buf[j + 4'd1] <= temp_val;
                            end
                            j <= j + 4'd1;
                        end else begin
                            i <= i + 4'd1;
                            // Go back to check outer loop condition
                            state <= SORT;
                        end
                    end
                end

                REVERSE: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE;
                    end else if (rev_idx < count / 4'd2) begin
                        // Swap elements from both ends
                        rev_temp <= temp_buf[rev_idx];
                        temp_buf[rev_idx] <= temp_buf[count - 4'd1 - rev_idx];
                        temp_buf[count - 4'd1 - rev_idx] <= rev_temp;
                        rev_idx <= rev_idx + 4'd1;
                    end else begin
                        // Reverse complete, move to map
                        state <= MAP;
                    end
                end

                MAP: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE;
                    end else if (map_idx < count) begin
                        // Map digit to string
                        case (temp_buf[map_idx])
                            8'd1: begin
                                case (map_idx)
                                    4'd0: result_0 <= STR_ONE;
                                    4'd1: result_1 <= STR_ONE;
                                    4'd2: result_2 <= STR_ONE;
                                    4'd3: result_3 <= STR_ONE;
                                    4'd4: result_4 <= STR_ONE;
                                    4'd5: result_5 <= STR_ONE;
                                    4'd6: result_6 <= STR_ONE;
                                    4'd7: result_7 <= STR_ONE;
                                endcase
                            end
                            8'd2: begin
                                case (map_idx)
                                    4'd0: result_0 <= STR_TWO;
                                    4'd1: result_1 <= STR_TWO;
                                    4'd2: result_2 <= STR_TWO;
                                    4'd3: result_3 <= STR_TWO;
                                    4'd4: result_4 <= STR_TWO;
                                    4'd5: result_5 <= STR_TWO;
                                    4'd6: result_6 <= STR_TWO;
                                    4'd7: result_7 <= STR_TWO;
                                endcase
                            end
                            8'd3: begin
                                case (map_idx)
                                    4'd0: result_0 <= STR_THREE;
                                    4'd1: result_1 <= STR_THREE;
                                    4'd2: result_2 <= STR_THREE;
                                    4'd3: result_3 <= STR_THREE;
                                    4'd4: result_4 <= STR_THREE;
                                    4'd5: result_5 <= STR_THREE;
                                    4'd6: result_6 <= STR_THREE;
                                    4'd7: result_7 <= STR_THREE;
                                endcase
                            end
                            8'd4: begin
                                case (map_idx)
                                    4'd0: result_0 <= STR_FOUR;
                                    4'd1: result_1 <= STR_FOUR;
                                    4'd2: result_2 <= STR_FOUR;
                                    4'd3: result_3 <= STR_FOUR;
                                    4'd4: result_4 <= STR_FOUR;
                                    4'd5: result_5 <= STR_FOUR;
                                    4'd6: result_6 <= STR_FOUR;
                                    4'd7: result_7 <= STR_FOUR;
                                endcase
                            end
                            8'd5: begin
                                case (map_idx)
                                    4'd0: result_0 <= STR_FIVE;
                                    4'd1: result_1 <= STR_FIVE;
                                    4'd2: result_2 <= STR_FIVE;
                                    4'd3: result_3 <= STR_FIVE;
                                    4'd4: result_4 <= STR_FIVE;
                                    4'd5: result_5 <= STR_FIVE;
                                    4'd6: result_6 <= STR_FIVE;
                                    4'd7: result_7 <= STR_FIVE;
                                endcase
                            end
                            8'd6: begin
                                case (map_idx)
                                    4'd0: result_0 <= STR_SIX;
                                    4'd1: result_1 <= STR_SIX;
                                    4'd2: result_2 <= STR_SIX;
                                    4'd3: result_3 <= STR_SIX;
                                    4'd4: result_4 <= STR_SIX;
                                    4'd5: result_5 <= STR_SIX;
                                    4'd6: result_6 <= STR_SIX;
                                    4'd7: result_7 <= STR_SIX;
                                endcase
                            end
                            8'd7: begin
                                case (map_idx)
                                    4'd0: result_0 <= STR_SEVEN;
                                    4'd1: result_1 <= STR_SEVEN;
                                    4'd2: result_2 <= STR_SEVEN;
                                    4'd3: result_3 <= STR_SEVEN;
                                    4'd4: result_4 <= STR_SEVEN;
                                    4'd5: result_5 <= STR_SEVEN;
                                    4'd6: result_6 <= STR_SEVEN;
                                    4'd7: result_7 <= STR_SEVEN;
                                endcase
                            end
                            8'd8: begin
                                case (map_idx)
                                    4'd0: result_0 <= STR_EIGHT;
                                    4'd1: result_1 <= STR_EIGHT;
                                    4'd2: result_2 <= STR_EIGHT;
                                    4'd3: result_3 <= STR_EIGHT;
                                    4'd4: result_4 <= STR_EIGHT;
                                    4'd5: result_5 <= STR_EIGHT;
                                    4'd6: result_6 <= STR_EIGHT;
                                    4'd7: result_7 <= STR_EIGHT;
                                endcase
                            end
                            8'd9: begin
                                case (map_idx)
                                    4'd0: result_0 <= STR_NINE;
                                    4'd1: result_1 <= STR_NINE;
                                    4'd2: result_2 <= STR_NINE;
                                    4'd3: result_3 <= STR_NINE;
                                    4'd4: result_4 <= STR_NINE;
                                    4'd5: result_5 <= STR_NINE;
                                    4'd6: result_6 <= STR_NINE;
                                    4'd7: result_7 <= STR_NINE;
                                endcase
                            end
                            default: begin
                                case (map_idx)
                                    4'd0: result_0 <= 32'd0;
                                    4'd1: result_1 <= 32'd0;
                                    4'd2: result_2 <= 32'd0;
                                    4'd3: result_3 <= 32'd0;
                                    4'd4: result_4 <= 32'd0;
                                    4'd5: result_5 <= 32'd0;
                                    4'd6: result_6 <= 32'd0;
                                    4'd7: result_7 <= 32'd0;
                                endcase
                            end
                        endcase
                        map_idx <= map_idx + 4'd1;
                    end else begin
                        // Map complete, go to done
                        valid_count <= count;
                        state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule