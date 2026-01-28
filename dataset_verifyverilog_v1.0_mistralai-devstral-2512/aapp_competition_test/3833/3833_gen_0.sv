module StringRearranger(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] t_bits,
    input wire [15:0] s_cnt0,
    input wire [15:0] s_cnt1,
    input wire [4:0] t_len,
    output reg out_char,
    output reg out_valid,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_KMP = 3'd1;
    localparam [2:0] CHECK_RESOURCES = 3'd2;
    localparam [2:0] OUTPUT_T = 3'd3;
    localparam [2:0] OUTPUT_REPEAT = 3'd4;
    localparam [2:0] OUTPUT_REMAINING = 3'd5;
    localparam [2:0] DONE_STATE = 3'd6;

    reg [2:0] state, next_state;

    // KMP prefix function storage
    reg [3:0] kmp_table [0:15];
    reg [3:0] overlap_len;

    // Repeating part counts
    reg [7:0] cnt_0, cnt_1;

    // Resource tracking
    reg [15:0] remaining_0, remaining_1;

    // Output tracking
    reg [7:0] output_index;
    reg [7:0] repeat_count;
    reg [7:0] total_length;

    // Temporary registers for computation
    reg [3:0] i, j;
    reg [3:0] temp_len;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            out_char <= 1'b0;
            out_valid <= 1'b0;
            done <= 1'b0;
            
            // Initialize all registers
            for (i = 0; i < 16; i = i + 1) begin
                kmp_table[i] <= 4'd0;
            end
            overlap_len <= 4'd0;
            cnt_0 <= 8'd0;
            cnt_1 <= 8'd0;
            remaining_0 <= 16'd0;
            remaining_1 <= 16'd0;
            output_index <= 8'd0;
            repeat_count <= 8'd0;
            total_length <= 8'd0;
            i <= 4'd0;
            j <= 4'd0;
            temp_len <= 4'd0;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        out_char = 1'b0;
        out_valid = 1'b0;
        done = 1'b0;

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = COMPUTE_KMP;
                end
            end

            COMPUTE_KMP: begin
                // Compute KMP prefix function
                if (i < t_len) begin
                    if (i == 4'd0) begin
                        kmp_table[i] = 4'd0;
                        i = i + 4'd1;
                    end else begin
                        j = kmp_table[i - 4'd1];
                        while (j > 4'd0 && t_bits[i] != t_bits[j]) begin
                            j = kmp_table[j - 4'd1];
                        end
                        if (t_bits[i] == t_bits[j]) begin
                            j = j + 4'd1;
                        end
                        kmp_table[i] = j;
                        i = i + 4'd1;
                    end
                end else begin
                    overlap_len = kmp_table[t_len - 4'd1];
                    i = 4'd0;
                    j = 4'd0;
                    next_state = CHECK_RESOURCES;
                end
            end

            CHECK_RESOURCES: begin
                // Calculate repeating part counts
                cnt_0 = 8'd0;
                cnt_1 = 8'd0;
                for (i = overlap_len; i < t_len; i = i + 1) begin
                    if (t_bits[i]) begin
                        cnt_1 = cnt_1 + 8'd1;
                    end else begin
                        cnt_0 = cnt_0 + 8'd1;
                    end
                end

                // Initialize remaining resources
                remaining_0 = s_cnt0;
                remaining_1 = s_cnt1;

                // Check if we can output t first
                if (remaining_0 >= (t_len - {16'd0, t_bits}) && 
                    remaining_1 >= {16'd0, t_bits}) begin
                    next_state = OUTPUT_T;
                    output_index = 8'd0;
                end else begin
                    next_state = OUTPUT_REPEAT;
                    output_index = 8'd0;
                    repeat_count = 8'd0;
                end
            end

            OUTPUT_T: begin
                if (output_index < t_len) begin
                    out_char = t_bits[output_index];
                    out_valid = 1'b1;
                    
                    // Update remaining resources
                    if (t_bits[output_index]) begin
                        remaining_1 = remaining_1 - 16'd1;
                    end else begin
                        remaining_0 = remaining_0 - 16'd1;
                    end
                    
                    output_index = output_index + 8'd1;
                end else begin
                    next_state = OUTPUT_REPEAT;
                    output_index = 8'd0;
                    repeat_count = 8'd0;
                end
            end

            OUTPUT_REPEAT: begin
                // Check if we can output another repeating part
                if (remaining_0 >= cnt_0 && remaining_1 >= cnt_1) begin
                    if (output_index < (t_len - overlap_len)) begin
                        out_char = t_bits[output_index + overlap_len];
                        out_valid = 1'b1;
                        
                        // Update remaining resources
                        if (t_bits[output_index + overlap_len]) begin
                            remaining_1 = remaining_1 - 16'd1;
                        end else begin
                            remaining_0 = remaining_0 - 16'd1;
                        end
                        
                        output_index = output_index + 8'd1;
                    end else begin
                        output_index = 8'd0;
                        repeat_count = repeat_count + 8'd1;
                    end
                end else begin
                    next_state = OUTPUT_REMAINING;
                    output_index = 8'd0;
                end
            end

            OUTPUT_REMAINING: begin
                if (remaining_0 > 16'd0) begin
                    out_char = 1'b0;
                    out_valid = 1'b1;
                    remaining_0 = remaining_0 - 16'd1;
                end else if (remaining_1 > 16'd0) begin
                    out_char = 1'b1;
                    out_valid = 1'b1;
                    remaining_1 = remaining_1 - 16'd1;
                end else begin
                    next_state = DONE_STATE;
                end
            end

            DONE_STATE: begin
                done = 1'b1;
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule