module remove_first_last_char(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] str_in [0:15],
    input wire [7:0] target_char,
    output reg [7:0] str_out [0:15],
    output reg done
);

    // State declarations
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] FIND_FIRST  = 3'd1;
    localparam [2:0] SHIFT_FIRST = 3'd2;
    localparam [2:0] FIND_LAST   = 3'd3;
    localparam [2:0] SHIFT_LAST  = 3'd4;
    localparam [2:0] DONE_STATE  = 3'd5;

    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Internal registers
    reg [7:0] temp_str [0:15];
    reg [3:0] length;
    reg [3:0] first_idx;
    reg [3:0] last_idx;
    reg [3:0] i;
    reg first_found;
    reg last_found;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 8'd0;
            done <= 1'b0;
            length <= 4'd0;
            first_idx <= 4'd0;
            last_idx <= 4'd0;
            i <= 4'd0;
            first_found <= 1'b0;
            last_found <= 1'b0;

            // Initialize output array
            integer j;
            for (j = 0; j < 16; j = j + 1) begin
                str_out[j] <= 8'd0;
                temp_str[j] <= 8'd0;
            end
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Copy input to temp_str
                        integer k;
                        for (k = 0; k < 16; k = k + 1) begin
                            temp_str[k] <= str_in[k];
                        end
                        
                        // Calculate initial length
                        length <= 4'd0;
                        for (k = 0; k < 16; k = k + 1) begin
                            if (str_in[k] != 8'd0) begin
                                length <= length + 4'd1;
                            end
                        end
                        
                        first_found <= 1'b0;
                        last_found <= 1'b0;
                        i <= 4'd0;
                        next_state <= FIND_FIRST;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                FIND_FIRST: begin
                    if (i < length && !first_found) begin
                        if (temp_str[i] == target_char) begin
                            first_idx <= i;
                            first_found <= 1'b1;
                        end
                        i <= i + 4'd1;
                        next_state <= FIND_FIRST;
                    end else begin
                        if (first_found) begin
                            i <= 4'd0;
                            next_state <= SHIFT_FIRST;
                        end else begin
                            // Character not found, go to DONE
                            next_state <= DONE_STATE;
                        end
                    end
                end

                SHIFT_FIRST: begin
                    if (i < length - 4'd1) begin
                        temp_str[i] <= temp_str[i + 4'd1];
                        i <= i + 4'd1;
                        next_state <= SHIFT_FIRST;
                    end else begin
                        length <= length - 4'd1;
                        temp_str[length] <= 8'd0;
                        i <= 4'd0;
                        next_state <= FIND_LAST;
                    end
                end

                FIND_LAST: begin
                    if (i < length && !last_found) begin
                        if (temp_str[i] == target_char) begin
                            last_idx <= i;
                            last_found <= 1'b1;
                        end
                        i <= i + 4'd1;
                        next_state <= FIND_LAST;
                    end else begin
                        if (last_found) begin
                            i <= 4'd0;
                            next_state <= SHIFT_LAST;
                        end else begin
                            // No last occurrence found, go to DONE
                            next_state <= DONE_STATE;
                        end
                    end
                end

                SHIFT_LAST: begin
                    if (i < length - 4'd1) begin
                        temp_str[i] <= temp_str[i + 4'd1];
                        i <= i + 4'd1;
                        next_state <= SHIFT_LAST;
                    end else begin
                        length <= length - 4'd1;
                        temp_str[length] <= 8'd0;
                        next_state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    // Copy result to output
                    integer m;
                    for (m = 0; m < 16; m = m + 1) begin
                        if (m < length) begin
                            str_out[m] <= temp_str[m];
                        end else begin
                            str_out[m] <= 8'd0;
                        end
                    end
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

    // Safety: force done to 0 after one cycle
    always @(posedge clk) begin
        if (state != DONE_STATE) begin
            done <= 1'b0;
        end
    end

    // Safety: prevent infinite loops
    always @(posedge clk) begin
        if (cycle_count >= MAX_CYCLES) begin
            state <= IDLE;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end
    end

endmodule